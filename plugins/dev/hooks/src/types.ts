export interface ToolCall {
  id?: string;
  name: string;
  args: string | Record<string, any>;
}

export interface PreToolInput {
  cwd?: string;
  toolCalls?: ToolCall[];
}

export interface PreToolOutput {
  permissionDecision?: "allow" | "deny";
  permissionDecisionReason?: string;
  modifiedArgs?: Record<string, any>;
  additionalContext?: string;
}

export interface PostToolInput {
  cwd?: string;
  toolName?: string;
  toolInput?: Record<string, any>;
  toolArgs?: Record<string, any>;
  toolResult?: {
    textResultForLlm?: string;
    resultType?: string;
    isError?: boolean | string;
    [key: string]: any;
  };
}

export interface PostToolOutput {
  modifiedResult?: {
    textResultForLlm?: string;
    resultType?: string;
    [key: string]: any;
  };
  additionalContext?: string;
}

export interface SessionStartInput {
  cwd?: string;
  timestamp?: number;
  source?: string;
}

export interface SessionStartOutput {
  additionalContext?: string;
}
