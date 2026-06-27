import { encodeValue } from "./value.js";

export function evaluate(
    code: string,
    { raw }: { raw: boolean }
): any {
    try {
        // eslint-disable-next-line no-eval
        const result = eval(code);

        if (raw) {
            return result;
        }

        return encodeValue(result);
    } catch (e) {
        return encodeValue(e);
    }
}

export interface CompletionItem {
    name: string;
    callable: boolean;
}

export function complete(
    code: string,
    cursor: number
): CompletionItem[] {
    const context = getContextAtCursor(code, cursor);
    const baseExpr = context.baseExpr;
    const fragment = context.fragment;

    let candidates: CompletionItem[];

    if (baseExpr !== null) {
        candidates = memberItems(resolveBase(baseExpr));
    } else {
        candidates = ownItems(globalThis);
    }

    if (baseExpr === null && fragment === "") {
        return [];
    }

    let filtered = candidates;

    if (fragment !== "") {
        filtered = candidates.filter(item => item.name.startsWith(fragment));
    }

    return filtered.slice(0, 256);
}

function memberItems(base: unknown): CompletionItem[] {
    if (base === null || base === undefined) {
        return [];
    }

    const seen = new Set<string>();
    const items: CompletionItem[] = [];
    let object: unknown = base;
    while (object !== null && object !== undefined) {
        for (const item of ownItems(object)) {
            if (seen.has(item.name)) {
                continue;
            }
            seen.add(item.name);
            items.push(item);
        }
        object = Object.getPrototypeOf(object);
    }
    return items;
}

function ownItems(object: unknown): CompletionItem[] {
    try {
        return Object.getOwnPropertyNames(object as object).map(raw => {
            const name = String(raw);
            const descriptor = Object.getOwnPropertyDescriptor(object as object, name);
            return { name, callable: typeof descriptor?.value === "function" };
        });
    } catch {
        return [];
    }
}

interface CompletionContext {
    baseExpr: string | null;
    fragment: string;
}

function getContextAtCursor(code: string, cursor: number): CompletionContext {
    const before = code.slice(0, cursor);

    let i = before.length - 1;
    while (i >= 0) {
        const ch = before[i];
        if (!/[A-Za-z0-9_$\\.]/.test(ch)) {
            break;
        }
        i -= 1;
    }

    const token = before.slice(i + 1);
    if (token === "") {
        return { baseExpr: null, fragment: "" };
    }

    const dotIndex = token.lastIndexOf(".");

    if (dotIndex === -1) {
        return {
            baseExpr: null,
            fragment: token
        };
    }

    const baseExpr = token.slice(0, dotIndex);
    const fragment = token.slice(dotIndex + 1);

    return {
        baseExpr,
        fragment
    };
}

function resolveBase(baseExpr: string | null): unknown {
    if (baseExpr === null) {
        return null;
    }

    try {
        // eslint-disable-next-line no-eval
        const base = eval(baseExpr);
        if (base === null || base === undefined) {
            return null;
        }
        return base;
    } catch {
        return null;
    }
}
