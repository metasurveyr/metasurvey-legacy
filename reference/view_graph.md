# View graph

View graph

## Usage

``` r
view_graph(svy, init_step = "Load survey")
```

## Arguments

- svy:

  Survey object

- init_step:

  Initial step label (default: "Load survey")

## Value

A visNetwork interactive graph of the survey processing steps.

## See also

Other steps:
[`bake_steps()`](https://metasurveyr.github.io/metasurvey/reference/bake_steps.md),
[`get_steps()`](https://metasurveyr.github.io/metasurvey/reference/get_steps.md),
[`step_collapse()`](https://metasurveyr.github.io/metasurvey/reference/step_collapse.md),
[`step_compute()`](https://metasurveyr.github.io/metasurvey/reference/step_compute.md),
[`step_filter()`](https://metasurveyr.github.io/metasurvey/reference/step_filter.md),
[`step_join()`](https://metasurveyr.github.io/metasurvey/reference/step_join.md),
[`step_quantile()`](https://metasurveyr.github.io/metasurvey/reference/step_quantile.md),
[`step_recode()`](https://metasurveyr.github.io/metasurvey/reference/step_recode.md),
[`step_remove()`](https://metasurveyr.github.io/metasurvey/reference/step_remove.md),
[`step_rename()`](https://metasurveyr.github.io/metasurvey/reference/step_rename.md),
[`step_validate()`](https://metasurveyr.github.io/metasurvey/reference/step_validate.md),
[`step_weight()`](https://metasurveyr.github.io/metasurvey/reference/step_weight.md)

## Examples

``` r
# \donttest{
dt <- data.table::data.table(
  id = 1:5, age = c(25, 30, 45, 50, 60),
  w = rep(1, 5)
)
svy <- Survey$new(
  data = dt, edition = "2023", type = "ech",
  psu = NULL, engine = "data.table",
  weight = add_weight(annual = "w")
)
svy <- step_compute(svy, age2 = age * 2)
view_graph(svy)

{"x":{"nodes":{"id":[1,2],"label":["Load survey","step_1 Compute: age2"],"title":["<div style='font-family: system-ui, -apple-system, sans-serif; padding: 12px 16px; max-width: 300px;'><div style='font-weight: 800; font-size: 14px; color: #2C3E50; margin-bottom: 8px;'>Survey<\/div><table style='font-size: 12px; color: #555; border-collapse: collapse;'><tr><td style='font-weight:600; padding: 3px 12px 3px 0; color:#2C3E50;'>Type<\/td><td style='padding:3px 0;'>ech<\/td><\/tr><tr><td style='font-weight:600; padding: 3px 12px 3px 0; color:#2C3E50;'>Edition<\/td><td style='padding:3px 0;'>2023<\/td><\/tr><tr><td style='font-weight:600; padding: 3px 12px 3px 0; color:#2C3E50;'>Weight<\/td><td style='padding:3px 0;'>Weight annual: w (Simple design)<\/td><\/tr><\/table><\/div>","<div style='font-family: system-ui, -apple-system, sans-serif; padding: 10px 14px; max-width: 340px;'><div style='font-weight: 700; font-size: 13px; color: #2C3E50; margin-bottom: 6px; border-bottom: 2px solid #eee; padding-bottom: 6px;'>Compute step<\/div><div style='font-family: SFMono-Regular, Consolas, monospace; font-size: 11px; color: #6c757d; background: #f8f9fa; padding: 8px 10px; border-radius: 6px; line-height: 1.5; white-space: pre-wrap;'>list(age2 = age * 2)<\/div><\/div>"],"group":["Load survey","compute"]},"edges":{"from":[1],"to":[2]},"nodesToDataframe":true,"edgesToDataframe":true,"options":{"width":"100%","height":"100%","nodes":{"shape":"dot"},"manipulation":{"enabled":false},"groups":{"Load survey":{"shape":"icon","icon":{"code":"f1c0","size":60,"color":"#2C3E50"},"font":{"size":16,"color":"#2C3E50","face":"bold","multi":true},"shadow":{"enabled":true,"size":8,"x":2,"y":2,"color":"rgba(44,62,80,.15)"}},"compute":{"shape":"icon","icon":{"code":"f1ec","size":50,"color":"#3498db"},"font":{"size":14,"color":"#2c3e50","face":"bold"},"shadow":{"enabled":true,"size":6,"x":2,"y":2,"color":"rgba(52,152,219,.2)"}},"recode":{"shape":"icon","icon":{"code":"f0e8","size":50,"color":"#9b59b6"},"font":{"size":14,"color":"#2c3e50","face":"bold"},"shadow":{"enabled":true,"size":6,"x":2,"y":2,"color":"rgba(155,89,182,.2)"}},"step_join":{"shape":"icon","icon":{"code":"f0c1","size":50,"color":"#1abc9c"},"font":{"size":14,"color":"#2c3e50","face":"bold"},"shadow":{"enabled":true,"size":6,"x":2,"y":2,"color":"rgba(26,188,156,.2)"}},"step_remove":{"shape":"icon","icon":{"code":"f1f8","size":50,"color":"#e74c3c"},"font":{"size":14,"color":"#2c3e50","face":"bold"},"shadow":{"enabled":true,"size":6,"x":2,"y":2,"color":"rgba(231,76,60,.2)"}},"step_rename":{"shape":"icon","icon":{"code":"f044","size":50,"color":"#e67e22"},"font":{"size":14,"color":"#2c3e50","face":"bold"},"shadow":{"enabled":true,"size":6,"x":2,"y":2,"color":"rgba(230,126,34,.2)"}},"validate":{"shape":"icon","icon":{"code":"f058","size":50,"color":"#27ae60"},"font":{"size":14,"color":"#2c3e50","face":"bold"},"shadow":{"enabled":true,"size":6,"x":2,"y":2,"color":"rgba(39,174,96,.2)"}},"useDefaultGroups":true,"dataframe":{"shape":"icon","icon":{"code":"f0ce","size":50,"color":"#95a5a6"},"font":{"size":14,"color":"#2c3e50"},"shadow":{"enabled":true,"size":6,"x":2,"y":2,"color":"rgba(149,165,166,.2)"}}},"edges":{"width":2,"arrows":{"to":{"enabled":true,"scaleFactor":0.7,"type":"arrow"}},"color":{"color":"#bdc3c7","highlight":"#3498db","hover":"#3498db"},"smooth":{"enabled":true,"type":"curvedCW","roundness":0.1}},"layout":{"hierarchical":{"enabled":true,"levelSeparation":220,"nodeSpacing":140,"direction":"LR","sortMethod":"directed"}},"interaction":{"keyboard":true,"navigationButtons":true,"tooltipDelay":100,"hover":true,"zoomSpeed":1},"clickToUse":false},"groups":["Load survey","compute"],"width":"100%","height":"600px","idselection":{"enabled":true,"style":"font-family: system-ui, sans-serif; font-size: 13px; padding: 6px 12px; border-radius: 8px; border: 1px solid #dee2e6; background: #fff; color: #2C3E50;","useLabels":true,"main":"Select by id"},"byselection":{"enabled":false,"style":"width: 150px; height: 26px","multiple":false,"hideColor":"rgba(200,200,200,0.5)","highlight":false},"main":null,"submain":null,"footer":null,"background":"#f8f9fa","iconsRedraw":true,"tooltipStay":300,"tooltipStyle":"position: fixed;visibility:hidden;padding: 5px;white-space: nowrap;font-family: verdana;font-size:14px;font-color:#000000;background-color: #f5f4ed;-moz-border-radius: 3px;-webkit-border-radius: 3px;border-radius: 3px;border: 1px solid #808074;box-shadow: 3px 3px 10px rgba(0, 0, 0, 0.2);","highlight":{"enabled":true,"hoverNearest":true,"degree":1,"algorithm":"all","hideColor":"rgba(200,200,200,0.5)","labelOnly":true},"collapse":{"enabled":false,"fit":false,"resetHighlight":true,"clusterOptions":null,"keepCoord":true,"labelSuffix":"(cluster)"},"legend":{"width":0.15,"useGroups":true,"position":"right","ncol":1,"stepX":100,"stepY":100,"zoom":false,"main":{"text":"Step types","style":"font-family: system-ui, sans-serif; font-weight: 700; font-size: 14px; color: #2C3E50;"}}},"evals":[],"jsHooks":[]}# }
```
