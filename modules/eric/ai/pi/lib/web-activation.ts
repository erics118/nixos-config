export const WEB_LOADER_NAME = "web_enable";

export const DEFAULT_WEB_TOOL_NAMES = [
  "web_search",
  "source_check",
  "fetch_content",
  "get_search_content",
] as const;

export const withLazyWebTools = (
  active: string[],
  webTools: readonly string[],
) => {
  const web = new Set(webTools);
  return [
    ...new Set([...active.filter((name) => !web.has(name)), WEB_LOADER_NAME]),
  ];
};

export const withEnabledWebTools = (
  active: string[],
  webTools: readonly string[],
) => [...new Set([...active, WEB_LOADER_NAME, ...webTools])];
