# Cursor Desktop (Windows) + Cloud Agents

This folder is the COMSOL Multiphysics MCP. Use it as its **own Cursor workspace**, not as a subdirectory of Sibyl, if you want it to show up as a separate repository group in Cloud Agents.

Dedicated GitHub repo (your fork):

https://github.com/makarovrush-ctrl/COMSOL_Multiphysics_MCP

Upstream:

https://github.com/wjc9011/COMSOL_Multiphysics_MCP

## Cloud Agents list

Cursor groups Cloud Agents by **GitHub repository**, not by folders inside another repo.

1. Open that fork in a browser and confirm it is yours.
2. Grant the **Cursor GitHub App** access to `makarovrush-ctrl/COMSOL_Multiphysics_MCP` (GitHub → Settings → Applications → Cursor → Repository access).
3. After that, the repo appears as its own group, the same way `comsol-mcp` / `solidworks-mcp` do.

A Linux Cloud Agent cannot run `C:\Program Files\COMSOL\...\win64\comsol.exe`. Drive COMSOL from **Cursor Desktop on the Windows PC that has COMSOL 6.2**.

## Windows Desktop MCP

COMSOL 6.2 on this machine is:

```
C:\Program Files\COMSOL\COMSOL62\Multiphysics_copy1\bin\win64\comsol.exe
```

That is `Multiphysics_copy1`, not the default `Multiphysics` folder. Project MCP config is `.cursor/mcp.json`.

In this folder:

```bat
py -3 -m pip install -e .
```

Then in Cursor: Settings → MCP → enable **comsol**.

First `comsol_start` only works if `bin\win64` is on `PATH` (the MCP `env` block already prepends it).
