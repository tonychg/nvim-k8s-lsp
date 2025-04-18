<div align="center">

# nvim-k8s-lsp

Experimental plugin to auto-detect Kubernetes schemas.

Inspired by [someone-stole-my-name/yaml-companion.nvim](https://github.com/someone-stole-my-name/yaml-companion.nvim)

</div>

## 🦶 Requirements

- [yaml-language-server](https://github.com/redhat-developer/yaml-language-server)
- [neovim](https://github.com/neovim/neovim) (0.11 or higher)
- [helm-ls](https://github.com/tonychg/helm-ls) (You need the patched version)

## 🍚 Concept

- Schemas detection
- Native CRD matching
- Minimalist
- Dynamic `yaml-language-server` and `helm-ls` reload

## 👍 Setup

### Plugin

**Lazy**

```lua
return {
  'tonychg/nvim-k8s-lsp',
  config = function()
    require("nvim-k8s-lsp").setup({
      kubernetes_version = "v1.32.2",
      lsp = {
        clients = {
          yaml = "yaml",
          helm = "helm",
        },
      },
      schema_stores = {
        kubernetes = {
          repo = "yannh/kubernetes-json-schema",
          branch = "master",
        },
        kubernetes_crds = {
          repo = "datreeio/CRDs-catalog",
          branch = "main",
        },
      },
      integrations = {
        lualine = false,
      },
    })
  end,
}
```

**nix**

```nix
{
    pkgs,
    ...
}: let
  nvim-k8s-lsp = pkgs.vimUtils.buildVimPlugin {
    pname = "nvim-k8s-lsp";
    version = "main";
    src = builtins.fetchGit {
      url = "https://github.com/tonychg/nvim-k8s-lsp.git";
      rev = "da0a121a34eabef458acda13997bc6ab69790073";
      ref = "main";
    };
  };
in
  programs.neovim = {
      plugins = with pkgs; [
          {
            plugin = nvim-k8s-lsp;
            type = "lua";
          }
      ]
      extraPackages = with pkgs; [
        yaml-language-server
      ]
  }
```

### Lsp

* `${XDG_CONFIG}/nvim/lsp/helm.lua`

```lua
return {
  cmd = { "/path/to/patch/version/helm_ls", "serve" },
  root_markers = { "values.yaml", "Chart.yaml" },
  settings = {
    ["helm-ls"] = {
      yamlls = {
        enabled = true,
        enabledForFilesGlob = "*.{yaml,yml}",
        diagnosticsLimit = 50,
        showDiagnosticsDirectly = false,
        config = {
          completion = true,
          hover = true,
          schemas = {
            -- Add pre-configured schemas
            -- Must not match any kubernetes manifests to avoid duplicate match
          },
        },
      },
    },
  },
}
```

* `${XDG_CONFIG}/nvim/lsp/yaml.lua`

```lua
return {
  cmd = { "yaml-language-server", "--stdio" },
  filetypes = { "yaml" },
  root_markers = { ".git", ".yamlfmt" },
  settings = {
    yaml = {
      schemaDownload = { enable = true },
      validate = true,
      hover = true,
      trace = { server = "debug" },
      schemas = {
        -- Add pre-configured schemas
        -- Must not match any kubernetes manifests to avoid duplicate match
      },
    },
  },
}
```

* `${XDG_CONFIG}/nvim/init.lua`

```lua
vim.lsp.enable("yaml")
vim.lsp.enable("helm")
```

## References

- https://github.com/someone-stole-my-name/yaml-companion.nvim
- https://github.com/mrjosh/helm-ls
- https://github.com/redhat-developer/yaml-language-server
- https://microsoft.github.io/language-server-protocol/
- https://neovim.io/doc/user/news-0.11.html
