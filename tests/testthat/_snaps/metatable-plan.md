# explain output snapshot

    Code
      print(explain(svy))
    Output
      <metatable plan> 4 pending steps
      -- segment 1
        [1] meta   step_rename  produces: edad | consumes: age
        [2] filter filter       produces: - | consumes: age
        [3] fence  validate     produces: - | consumes: age
      -- segment 2
        [4] meta   step_remove  produces: y | consumes: -
      Passes over the data: 2 (current engine) -> 2 (planned, no optimization rules yet)

