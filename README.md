# nvim-k8s-lsp

## 🦶 Requirements

- [yaml-language-server](https://github.com/redhat-developer/yaml-language-server)
- [neovim](https://github.com/neovim/neovim) (0.11 or higher)

## 🍚 Concept

- Schemas detection
- Native CRD matching
- Minimalist

## 👍 Setup

**Lazy**

```lua
return {
  'tonychg/nvim-k8s-lsp',
  config = function()
    require("nvim-k8s-lsp").setup({
        kubernetes_version = "v1.32.2",
        integrations = {
            lualine = false,
        }
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

## 🪜 TODO

- Support [helm_ls](https://github.com/mrjosh/helm-ls)
