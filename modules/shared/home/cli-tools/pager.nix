_:

let
  sessionVariables = {
    PAGER = "less";
    LESS = "-R --quit-if-one-screen --no-init";
  };
in
{
  home = { inherit sessionVariables; };
  myOptions.developerEnvironmentParity.surfaces.cliPager = { inherit sessionVariables; };
}
