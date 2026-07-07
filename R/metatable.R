# metatable engine — logical plan for the step pipeline
#
# Design: design/metatable-rfc.md (issue #214). This file implements the
# PR 1 foundations of §6: the plan structures (§2.1), the narrow/wide
# classification table (§2.2), build_plan() (§3) and explain(). No
# optimization rule is active yet: the plan mirrors the effective bake
# order of the current engine and the passthrough executor delegates
# every node to bake_step() (see bake_steps_survey(), R/Step.R).

#' Valid values for meta_node classification fields
#' @noRd
meta_node_kinds <- function() {
  c("narrow", "wide", "filter", "fence", "meta")
}

#' @noRd
meta_node_row_effects <- function() {
  c("none", "subset", "reshape")
}

#' Create a plan node (one per pending Step)
#'
#' Base R list with S3 class (no R6: the plan is an immutable and
#' ephemeral value, RFC §2.1). `step` keeps a reference to the original
#' Step object (not a clone) so the executor can delegate to
#' `bake_step()` without translation.
#'
#' @param step_idx Integer index of the step in the list handed to
#'   `build_plan()` (remapped to the index in `svy$steps` by the
#'   executor for traceability).
#' @param step The original `Step` object.
#' @param kind Classification: `"narrow"`, `"wide"`, `"filter"`,
#'   `"fence"` or `"meta"` (RFC §2.2).
#' @param produces Character vector of columns the step creates,
#'   modifies or (for remove) deletes.
#' @param consumes Character vector of columns the step reads
#'   (`depends_on` plus grouping variables and join keys).
#' @param row_effect `"none"`, `"subset"` or `"reshape"`.
#' @param group_vars Character vector of grouping variables or NULL.
#' @return A `meta_node` object.
#' @noRd
#' @keywords internal
meta_node <- function(step_idx, step, kind,
                      produces = character(0),
                      consumes = character(0),
                      row_effect = "none",
                      group_vars = NULL) {
  if (!kind %in% meta_node_kinds()) {
    stop(
      "Invalid meta_node kind: '", kind, "'. Must be one of: ",
      paste(meta_node_kinds(), collapse = ", "),
      call. = FALSE
    )
  }
  if (!row_effect %in% meta_node_row_effects()) {
    stop(
      "Invalid meta_node row_effect: '", row_effect,
      "'. Must be one of: ",
      paste(meta_node_row_effects(), collapse = ", "),
      call. = FALSE
    )
  }
  structure(
    list(
      step_idx = as.integer(step_idx),
      step = step,
      kind = kind,
      produces = as.character(produces),
      consumes = as.character(consumes),
      row_effect = row_effect,
      group_vars = group_vars
    ),
    class = "meta_node"
  )
}

#' Create a logical plan
#'
#' @param nodes List of `meta_node` objects in effective execution order.
#' @param sinks Character vector of columns required downstream, or NULL
#'   when the consumer is unknown (= all columns are observable, no
#'   projection pruning; RFC §4.2).
#' @return A `meta_plan` object.
#' @noRd
#' @keywords internal
meta_plan <- function(nodes = list(), sinks = NULL) {
  structure(
    list(
      nodes = nodes,
      sinks = sinks,
      schedule = list(),
      stats = list()
    ),
    class = "meta_plan"
  )
}

#' Classify a step as narrow/wide/filter/fence/meta
#'
#' Implements the classification table of RFC §2.2. A step is *narrow*
#' if its effect on each row depends only on that row; *wide* if it
#' depends on the whole row set (grouped aggregation, join, external
#' alignment); *filter* selects rows; *fence* observes or requires an
#' exact global state (nothing can move across it); *meta* only touches
#' the schema.
#'
#' `step_quantile` and `step_collapse` (added after the RFC snapshot)
#' are classified conservatively as wide: weighted quantile groups
#' depend on the full row set, and a collapse changes row multiplicity
#' (`row_effect = "reshape"`), like a join.
#'
#' @param step A `Step` object.
#' @return A list with elements `kind` and `row_effect`.
#' @noRd
#' @keywords internal
classify_step <- function(step) {
  has_by <- !is.null(step$by_vars) && length(step$by_vars) > 0
  switch(step$type,
    # compute without .by: single row-local `:=` pass, fusable
    # compute with .by: result depends on the whole group
    compute = if (has_by) {
      list(kind = "wide", row_effect = "none")
    } else {
      list(kind = "narrow", row_effect = "none")
    },
    # first-match-wins over each row's own values: row-local
    recode = list(kind = "narrow", row_effect = "none"),
    # changes row multiplicity and column set, mutates weights
    step_join = list(kind = "wide", row_effect = "reshape"),
    # schema only (O(1)); anti-dependency through `produces`
    step_remove = list(kind = "meta", row_effect = "none"),
    # schema only; the planner applies the mapping to later nodes
    step_rename = list(kind = "meta", row_effect = "none"),
    # filter without .by commutes with narrow; with .by the condition
    # can be group-level and `by=` regroups the output
    filter = if (has_by) {
      list(kind = "wide", row_effect = "subset")
    } else {
      list(kind = "filter", row_effect = "subset")
    },
    # observes the exact current state (incl. row counts via .min_n)
    validate = list(kind = "fence", row_effect = "none"),
    # positional alignment with external data + design mutation
    step_weight = list(kind = "fence", row_effect = "none"),
    step_quantile = list(kind = "wide", row_effect = "none"),
    step_collapse = list(kind = "wide", row_effect = "reshape"),
    # same pattern as the bake_step() whitelist (R/Step.R): new step
    # types must be classified explicitly or the metatable engine
    # refuses to plan them (RFC §8)
    stop(
      "classify_step(): unknown step type '", step$type,
      "'. Add it to the classification table in R/metatable.R ",
      "(see design/metatable-rfc.md, section 2.2).",
      call. = FALSE
    )
  )
}

#' Columns a step creates, modifies or deletes
#'
#' Derived from what each step already records (RFC §2.1): `new_var`
#' in compute/recode/weight/quantile, `mapping` in rename, `vars` in
#' remove, and the RHS column names for join.
#' @param step A `Step` object.
#' @return Character vector (possibly empty).
#' @noRd
#' @keywords internal
step_outputs <- function(step) {
  switch(step$type,
    compute = {
      # compute stores the new names as a comma-separated string
      nv <- step$new_var
      if (is.null(nv) || !nzchar(nv)) {
        character(0)
      } else {
        strsplit(nv, ", ", fixed = TRUE)[[1L]]
      }
    },
    recode = ,
    step_weight = ,
    step_quantile = as.character(step$new_var %||% character(0)),
    step_join = {
      x <- step$exprs$x
      rhs <- if (methods::is(x, "Survey")) get_data(x) else x
      if (is.data.frame(rhs)) names(rhs) else character(0)
    },
    step_remove = as.character(step$exprs$vars %||% character(0)),
    step_rename = names(step$exprs$mapping %||% character(0)),
    # filter / validate / step_collapse produce no columns
    character(0)
  )
}

#' Columns a step reads
#'
#' `depends_on` plus the grouping variables. Join keys are already in
#' `depends_on` (step_join records `by.x`). Rename consumes the old
#' names of its mapping.
#' @param step A `Step` object.
#' @return Character vector (possibly empty).
#' @noRd
#' @keywords internal
step_inputs <- function(step) {
  extra <- if (identical(step$type, "step_rename")) {
    unname(step$exprs$mapping)
  } else {
    NULL
  }
  unique(as.character(c(unlist(step$depends_on), step$by_vars, extra)))
}

#' Translate column names through an accumulated rename map
#'
#' @param x Character vector of column names (post-rename space).
#' @param rename_map Named character vector mapping current name ->
#'   original name.
#' @return `x` with renamed columns replaced by their original names.
#' @noRd
#' @keywords internal
translate_names <- function(x, rename_map) {
  if (length(x) == 0 || length(rename_map) == 0) {
    return(x)
  }
  hit <- x %in% names(rename_map)
  x[hit] <- unname(rename_map[x[hit]])
  x
}

#' Compose the rename map with a step_rename mapping
#'
#' `mapping` is the named character vector recorded by step_rename
#' (`new_name = old_name`, old names in the current naming space).
#' The result maps each current name to its original (pre-plan) name,
#' so `consumes`/`produces` of later nodes can be expressed in the
#' original space for dependency analysis (RFC §3).
#'
#' step_rename applies its whole mapping in a single vectorized
#' `setnames()` call (R/steps.R), i.e. atomically: every old name is
#' resolved in the naming space *before* the step. Composition must
#' therefore resolve all origins against a snapshot of the accumulated
#' map, never against a partially updated one — otherwise swaps
#' (`c(a = "b", b = "a")`) and chains (`c(b = "a", c = "b")`) inside a
#' single step corrupt the map.
#' @noRd
#' @keywords internal
compose_rename_map <- function(rename_map, mapping) {
  # 1) resolve every origin against the pre-step snapshot
  origins <- vapply(
    unname(mapping),
    function(old) if (old %in% names(rename_map)) rename_map[[old]] else old,
    character(1)
  )
  # 2) all old current-space names disappear atomically after the rename
  rename_map <- rename_map[!names(rename_map) %in% unname(mapping)]
  # 3) insert all the new names at once
  rename_map[names(mapping)] <- origins
  rename_map
}

#' Build the logical plan for a list of pending steps
#'
#' Implements the pseudocode of RFC §3: one node per step, classified
#' with `classify_step()`, with `consumes`/`produces` translated through
#' the rename map accumulated from the `step_rename` nodes seen so far.
#' The node order is the effective bake order of the current engine
#' (`bake_steps_survey()` executes pending steps in registration order),
#' which is the semantic reference for any future optimization rule.
#'
#' @param steps List of `Step` objects, already filtered to the pending
#'   ones (`bake = FALSE`) in effective execution order.
#' @param sinks Character vector of columns required downstream, or
#'   NULL when the consumer is unknown (no projection pruning).
#' @param on_unknown What to do with a step type missing from the
#'   classification table. `"error"` (default, used by `explain()`)
#'   fails at plan time with the explicit `classify_step()` message
#'   (RFC §8). `"passthrough"` (used by the bake executor) leaves the
#'   node NULL so the executor falls back to `bake_step()`, which
#'   raises its whitelist error at that node's position with all
#'   previous steps already executed — same error timing and same
#'   post-error state as the data.table engine (contract §5.2).
#' @return A `meta_plan` object.
#' @noRd
#' @keywords internal
build_plan <- function(steps, sinks = NULL,
                       on_unknown = c("error", "passthrough")) {
  on_unknown <- match.arg(on_unknown)
  nodes <- vector("list", length(steps))
  rename_map <- character(0)
  for (i in seq_along(steps)) {
    step <- steps[[i]]
    cls <- if (identical(on_unknown, "passthrough")) {
      tryCatch(classify_step(step), error = function(e) NULL)
    } else {
      classify_step(step)
    }
    if (is.null(cls)) {
      # unknown type: no node — the executor delegates this position
      # to bake_step(), preserving the current engine's error message,
      # error order and partial state (previous steps applied)
      next
    }
    nodes[[i]] <- meta_node(
      step_idx = i,
      step = step,
      kind = cls$kind,
      produces = translate_names(step_outputs(step), rename_map),
      consumes = translate_names(step_inputs(step), rename_map),
      row_effect = cls$row_effect,
      group_vars = step$by_vars
    )
    if (identical(step$type, "step_rename")) {
      rename_map <- compose_rename_map(rename_map, step$exprs$mapping)
    }
  }
  meta_plan(nodes = nodes, sinks = sinks)
}

#' Plan nodes indexed by position in svy$steps (passthrough executor)
#'
#' Builds the plan for the pending steps and returns a list parallel to
#' `steps`: element `i` is the `meta_node` for `steps[[i]]` (with
#' `step_idx` remapped to `i`), or NULL if the step is already baked.
#' Returns NULL when there is nothing to plan, so callers can fall back
#' to the default path with zero overhead.
#' @param steps The full `svy$steps` list.
#' @return List of `meta_node`/NULL, or NULL.
#' @noRd
#' @keywords internal
metatable_plan_nodes <- function(steps) {
  pending <- which(
    !vapply(steps, function(s) isTRUE(s$bake), logical(1))
  )
  if (length(pending) == 0L) {
    return(NULL)
  }
  # on_unknown = "passthrough": a step type missing from the
  # classification table must NOT abort the bake at plan time — the
  # data.table engine only errors when the loop reaches that step
  # (bake_step() whitelist), with the previous pending steps already
  # applied. Its node stays NULL and the executor falls back to
  # bake_step() at the same position (contract §5.2).
  plan <- build_plan(steps[pending], on_unknown = "passthrough")
  nodes <- vector("list", length(steps))
  for (k in seq_along(pending)) {
    node <- plan$nodes[[k]]
    if (is.null(node)) {
      next
    }
    node$step_idx <- pending[[k]]
    nodes[[pending[[k]]]] <- node
  }
  nodes
}

#' Explain the execution plan of the pending steps
#'
#' Builds the `metatable` logical plan for the pending (not yet baked)
#' steps of a survey and returns it without executing anything. The
#' print method shows the classification of each node
#' (narrow/wide/filter/fence/meta), the segments cut at fence nodes,
#' and the number of passes over the data of the current engine versus
#' the plan (identical for now: no optimization rule is active yet).
#'
#' `explain()` never touches the data: it only inspects the step
#' metadata, regardless of the configured engine.
#'
#' @param svy A `Survey` object.
#' @return A `meta_plan` object (invisibly printable). With no pending
#'   steps the plan is empty and the print method says so.
#' @examples
#' dt <- data.table::data.table(
#'   id = 1:6, age = c(15, 25, 35, 45, 55, 65), w = 1
#' )
#' svy <- Survey$new(
#'   data = dt, edition = "2023", type = "test",
#'   psu = NULL, engine = "data.table", weight = add_weight(annual = "w")
#' )
#' svy <- svy |>
#'   step_rename(edad = age) |>
#'   step_filter(edad >= 18) |>
#'   step_validate(edad > 0)
#' explain(svy)
#' @seealso [bake_steps()] to execute the pending steps.
#' @family steps
#' @export
explain <- function(svy) {
  if (!is(svy, "Survey")) {
    stop(
      "explain() requires a Survey object. For a RotativePanelSurvey, ",
      "explain the implantation or a follow-up survey directly.",
      call. = FALSE
    )
  }
  pending <- Filter(function(s) !isTRUE(s$bake), svy$steps)
  build_plan(pending)
}

#' @describeIn explain Print method for the plan returned by `explain()`.
#' @param x A `meta_plan` object.
#' @param ... Ignored.
#' @export
print.meta_plan <- function(x, ...) {
  n_nodes <- length(x$nodes)
  if (n_nodes == 0) {
    cat("<metatable plan> no pending steps: nothing to plan\n")
    return(invisible(x))
  }
  cat(sprintf(
    "<metatable plan> %d pending step%s\n",
    n_nodes, if (n_nodes == 1) "" else "s"
  ))
  segment <- 1L
  open_segment <- FALSE
  fmt_cols <- function(v) {
    if (length(v) == 0) "-" else paste(v, collapse = ", ")
  }
  for (node in x$nodes) {
    if (!open_segment) {
      cat(sprintf("-- segment %d\n", segment))
      open_segment <- TRUE
    }
    cat(sprintf(
      "  [%d] %-6s %-12s produces: %s | consumes: %s%s\n",
      node$step_idx,
      node$kind,
      node$step$type,
      fmt_cols(node$produces),
      fmt_cols(node$consumes),
      if (is.null(node$group_vars)) {
        ""
      } else {
        sprintf(" | by: %s", paste(node$group_vars, collapse = ", "))
      }
    ))
    if (identical(node$kind, "fence")) {
      # fences split the plan: the optimizer works independently on
      # each segment between fences (RFC §2.2)
      segment <- segment + 1L
      open_segment <- FALSE
    }
  }
  # meta nodes only touch the schema (O(1)): every other node is one
  # pass over the data. Without optimization rules the planned passes
  # equal the current engine's passes.
  passes <- sum(
    vapply(x$nodes, function(node) node$kind != "meta", logical(1))
  )
  cat(sprintf(
    "Passes over the data: %d (current engine) -> %d (planned, no optimization rules yet)\n",
    passes, passes
  ))
  invisible(x)
}
