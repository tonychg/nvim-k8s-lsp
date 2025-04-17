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

## 🪜 TODO

- Support [helm_ls](https://github.com/mrjosh/helm-ls)
