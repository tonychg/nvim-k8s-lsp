local M = {
  default_options = {
    kubernetes_version = "v1.32.2",
    integrations = {
      lualine = false,
    },
  },
  config = {},
}

local store_builtins_url =
  "https://raw.githubusercontent.com/yannh/kubernetes-json-schema/refs/heads/master/%s-standalone-strict/%s-%s.json"
local store_crds_url = "https://raw.githubusercontent.com/datreeio/CRDs-catalog/refs/heads/main/%s/%s_%s.json"

local function table_contains(tbl, x)
  local found = false
  for _, v in pairs(tbl) do
    if v == x then
      found = true
    end
  end
  return found
end

local function extract_api_version(line)
  local _, e = vim.regex([[^apiVersion: .*$]]):match_str(line)
  if e then
    return string.sub(line, 13, e)
  end
end

local function extract_kind(line)
  local _, e = vim.regex([[^kind: .*$]]):match_str(line)
  if e then
    return string.sub(line, 7, e)
  end
end

local function is_builtin(attributes)
  local builtins = require("nvim-k8s-lsp.builtins")
  return table_contains(builtins, attributes.kind)
end

local function is_helm()
  local filepath = vim.fn.expand("%:p")
  if vim.regex([[\v(templates).*\.(ya?ml|tpl|txt)$]]):match_str(filepath) then
    return true
  end
  return false
end

function M.get_schema_url(attributes)
  local schema_url
  local kind = string.lower(attributes.kind)
  local group = attributes.group
  local version = attributes.version
  local base_url = store_builtins_url

  if is_builtin(attributes) then
    local suffix = attributes.version
    if attributes.group == "rbac.authorization.k8s.io" then
      group = "rbac"
    end
    if attributes.group == "networking.k8s.io" then
      group = "networking"
    end
    if attributes.group then
      suffix = string.format("%s-%s", group, version)
    end
    schema_url = string.format(base_url, M.config.kubernetes_version, kind, suffix)
  else
    base_url = store_crds_url
    schema_url = string.format(base_url, group, kind, version)
  end

  return schema_url
end

local function build_schemas(source_schemas, schema_url, bufuri)
  local schemas = { [schema_url] = { bufuri } }

  if source_schemas then
    schemas = vim.tbl_deep_extend("keep", source_schemas, schemas)
    for k, v in pairs(source_schemas) do
      if k == schema_url then
        local files = v
        if not table_contains(files, bufuri) then
          table.insert(files, bufuri)
        end
        schemas[k] = files
      end
    end
  end

  return schemas
end

function M.extract_api_attributes(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local attributes = {}

  for _, line in ipairs(lines) do
    local api_version = extract_api_version(line)

    if api_version then
      local split = vim.split(api_version, "/", { plain = true })
      if #split == 2 then
        attributes.group = split[1]
        attributes.version = split[2]
      end
      if #split == 1 then
        attributes.version = split[1]
      end
    end

    local kind = extract_kind(line)

    if kind then
      attributes.kind = kind
    end
  end

  return attributes
end

function M.lualine()
  local attributes = M.extract_api_attributes(vim.api.nvim_get_current_buf())
  local helm_suffix = ""
  if is_helm() then
    helm_suffix = ":helm"
  end
  if attributes.kind then
    return string.format([[%s:%s%s]], M.config.kubernetes_version, attributes.kind, helm_suffix)
  else
    return [[]]
  end
end

function M.reload_yaml_lsp(client, bufnr, settings)
  local bufuri = vim.uri_from_bufnr(bufnr)

  if client.name == "helm" then
    client:notify("workspace/didChangeConfiguration", { settings = settings }, 50000, bufnr)
  else
    client:notify("workspace/didChangeConfiguration", { settings = settings }, 50000, bufnr)
    client:request_sync("yaml/get/jsonSchema", { bufuri }, 50000, bufnr)
  end
end

function M.deactivate_other_lsp(bufnr)
  local clients = vim.lsp.get_clients({ bufnr = bufnr })

  for _, client in pairs(clients) do
    if is_helm() then
      if client.name == "yaml" then
        vim.lsp.stop_client(client.id, true)
      end
    else
      if client.name == "helm" then
        vim.lsp.stop_client(client.id, true)
      end
    end
  end
end

function M.associate_schema_to_buffer(client, bufnr)
  local attributes = M.extract_api_attributes(bufnr)

  if attributes.kind and attributes.version then
    local schema_url = M.get_schema_url(attributes)
    local bufuri = vim.uri_from_bufnr(bufnr)

    if client.name == "yaml" and not is_helm() then
      local settings = client.settings
      local schemas = build_schemas(settings.yaml.schemas, schema_url, bufuri)
      settings.yaml.schemas = schemas
      M.reload_yaml_lsp(client, bufnr, settings)
    end

    if client.name == "helm" then
      local settings = client.settings
      if settings["helm-ls"] and settings["helm-ls"].yamlls and settings["helm-ls"].yamlls.config then
        local yaml_settings = settings["helm-ls"].yamlls.config
        local schemas = build_schemas(yaml_settings.schemas, schema_url, bufuri)
        yaml_settings.schemas = schemas
        M.reload_yaml_lsp(client, bufnr, yaml_settings)
      end
    end
  end
end

function M.load_lualine()
  local lualine = require("lualine")

  if lualine then
    local config = lualine.get_config()
    local lualine_x = { M.lualine }
    for _, v in pairs(config.sections.lualine_x) do
      table.insert(lualine_x, v)
    end
    config.sections.lualine_x = lualine_x
    lualine.setup(config)
  end
end

function M.switch_version(kubernetes_version)
  M.config.kubernetes_version = kubernetes_version
end

function M.setup(user_configuration)
  user_configuration = user_configuration or {}

  M.config = vim.tbl_deep_extend("keep", user_configuration, M.default_options)

  if M.config.integrations.lualine then
    M.load_lualine()
  end

  vim.api.nvim_create_user_command("KubeSwitchVersion", function(inp)
    M.switch_version(inp.args)
  end, { nargs = 1 })

  vim.api.nvim_create_autocmd("LspAttach", {
    pattern = { "*.yaml", "*.yml" },
    callback = function(event)
      local client = vim.lsp.get_client_by_id(event.data.client_id)
      local bufnr = vim.api.nvim_get_current_buf()
      if not client then
        return
      end
      if client.name == "yaml" or client.name == "helm" then
        M.deactivate_other_lsp(bufnr)
        M.associate_schema_to_buffer(client, bufnr)
      end
    end,
  })
end

return M
