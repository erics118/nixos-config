export interface ExtractedOption {
  label: string;
  text: string;
}

export interface ExtractedQuestion {
  question: string;
  context?: string;
  options?: ExtractedOption[];
}

export interface ExtractionResult {
  questions: ExtractedQuestion[];
}

const toExtractedOption = (value: unknown): ExtractedOption | null => {
  if (
    typeof value !== "object" ||
    value === null ||
    !("label" in value) ||
    !("text" in value) ||
    typeof value.label !== "string" ||
    typeof value.text !== "string"
  )
    return null;
  return { label: value.label, text: value.text };
};

const toExtractedQuestion = (value: unknown): ExtractedQuestion | null => {
  if (typeof value !== "object" || value === null || !("question" in value))
    return null;
  const context = "context" in value ? value.context : undefined;
  const options = "options" in value ? value.options : undefined;
  if (typeof value.question !== "string") return null;
  if (context !== undefined && context !== null && typeof context !== "string")
    return null;
  if (options !== undefined && options !== null && !Array.isArray(options))
    return null;
  const parsedOptions = options?.map(toExtractedOption) ?? [];
  if (parsedOptions.some((option) => option === null)) return null;

  const result: ExtractedQuestion = { question: value.question };
  if (typeof context === "string" && context.length > 0)
    result.context = context;
  if (parsedOptions.length > 0) {
    result.options = parsedOptions.filter(
      (option): option is ExtractedOption => option !== null,
    );
  }
  return result;
};

const validateExtractionResult = (value: unknown): ExtractionResult | null => {
  if (
    typeof value !== "object" ||
    value === null ||
    !("questions" in value) ||
    !Array.isArray(value.questions)
  ) {
    return null;
  }
  const questions = value.questions.map(toExtractedQuestion);
  if (questions.some((question) => question === null)) return null;
  return {
    questions: questions.filter(
      (question): question is ExtractedQuestion => question !== null,
    ),
  };
};

export function parseExtractionResult(text: string): ExtractionResult | null {
  const candidates: string[] = [];
  const fenced = Array.from(
    text.matchAll(/```([a-z0-9_-]+)?\s*\n?([\s\S]*?)```/gi),
    (match) => ({ language: match[1]?.toLowerCase(), content: match[2]!.trim() }),
  );
  candidates.push(
    ...fenced
      .filter((block) => block.language === "json")
      .map((block) => block.content),
    ...fenced
      .filter((block) => block.language !== "json")
      .map((block) => block.content),
  );
  const trimmed = text.trim();
  candidates.push(trimmed);
  const firstBrace = trimmed.indexOf("{");
  const lastBrace = trimmed.lastIndexOf("}");
  if (firstBrace !== -1 && lastBrace > firstBrace)
    candidates.push(trimmed.slice(firstBrace, lastBrace + 1));

  for (const candidate of candidates) {
    try {
      const result = validateExtractionResult(JSON.parse(candidate));
      if (result) return result;
    } catch {
      // try the next candidate
    }
  }
  return null;
}
