local M = {}
local config

local store_builtins_url =
  "https://raw.githubusercontent.com/yannh/kubernetes-json-schema/refs/heads/master/%s-standalone-strict/%s-%s-%s.json"
local store_crds_url = "https://raw.githubusercontent.com/datreeio/CRDs-catalog/refs/heads/main/%s/%s_%s.json"

local defaults = {
  kubernetes_version = "v1.32.2",
}

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

local function get_schema_url(kubernetes_version, attributes)
  local schema_url
  local kind = string.lower(attributes.kind)
  local group = attributes.group
  local version = attributes.version
  local base_url = store_builtins_url

  if is_builtin(attributes) then
    schema_url = string.format(base_url, kubernetes_version, kind, group, version)
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

function M:extract_api_attributes(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local attributes = {}

  for _, line in ipairs(lines) do
    local api_version = extract_api_version(line)

    if api_version then
      local split = vim.split(api_version, "/", { plain = true })
      attributes.group = split[1]
      attributes.version = split[2]
    end

    local kind = extract_kind(line)

    if kind then
      attributes.kind = kind
    end
  end

  return attributes
end

function M:reload_yaml_lsp(client, bufnr, settings)
  local bufuri = vim.uri_from_bufnr(bufnr)

  client:notify("workspace/didChangeConfiguration", { settings = settings }, 50000, bufnr)
  client:request_sync("yaml/get/jsonSchema", { bufuri }, 50000, bufnr)
end

function M:associate_schema_to_buffer(client, bufnr)
  local attributes = M:extract_api_attributes(bufnr)

  if attributes.kind and attributes.version and attributes.group then
    local schema_url = get_schema_url(config.kubernetes_version, attributes)
    local settings = client.settings
    local bufuri = vim.uri_from_bufnr(bufnr)
    local schemas = build_schemas(settings.yaml.schemas, schema_url, bufuri)
    settings.yaml.schemas = schemas
    M:reload_yaml_lsp(client, bufnr, settings)
  end
end

function M:setup(opts)
  config = defaults

  if opts then
    config = vim.tbl_deep_extend("force", opts, config)
  end

  vim.api.nvim_create_autocmd("LspAttach", {
    pattern = { "*.yaml", "*.yml" },
    callback = function(event)
      local client = vim.lsp.get_client_by_id(event.data.client_id)
      local bufnr = vim.api.nvim_get_current_buf()
      if not client then
        return
      end
      if client.name == "yaml" then
        M:associate_schema_to_buffer(client, bufnr)
      end
    end,
  })
end

return M
