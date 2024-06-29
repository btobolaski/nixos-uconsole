{
  "6.1-potatomania" = {...}: {
    imports = [ ./6.1-potatomania ];
    uconsole.boot.kernel.crossBuild = false;
  };
  "6.1-potatomania-cross-build" = {
    imports = [ ./6.1-potatomania ];
    uconsole.boot.kernel.crossBuild = true;
  };
  "6.6-potatomania" = {...}: {
    imports = [ ./6.6-potatomania ];
    uconsole.boot.kernel.crossBuild = false;
  };
  "6.6-potatomania-cross-build" = {
    imports = [ ./6.6-potatomania ];
    uconsole.boot.kernel.crossBuild = true;
  };
}
