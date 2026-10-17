import { createElement, type ReactNode } from "react";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import V3HomepageInteractions from "./v3-homepage-interactions";

type HtmlNode =
  | { type: "text"; value: string }
  | {
      type: "element";
      tag: string;
      attributes: Record<string, string | true>;
      children: HtmlNode[];
    };

const VOID_ELEMENTS = new Set([
  "area",
  "base",
  "br",
  "col",
  "embed",
  "hr",
  "img",
  "input",
  "link",
  "meta",
  "param",
  "source",
  "track",
  "wbr",
]);

const BOOLEAN_ATTRIBUTES = new Set([
  "allowfullscreen",
  "async",
  "autofocus",
  "autoplay",
  "checked",
  "controls",
  "default",
  "defer",
  "disabled",
  "formnovalidate",
  "hidden",
  "inert",
  "ismap",
  "itemscope",
  "loop",
  "multiple",
  "muted",
  "nomodule",
  "novalidate",
  "open",
  "playsinline",
  "readonly",
  "required",
  "reversed",
  "selected",
]);

const ATTRIBUTE_NAMES: Record<string, string> = {
  class: "className",
  for: "htmlFor",
  tabindex: "tabIndex",
  readonly: "readOnly",
  maxlength: "maxLength",
  minlength: "minLength",
  colspan: "colSpan",
  rowspan: "rowSpan",
  cellpadding: "cellPadding",
  cellspacing: "cellSpacing",
  crossorigin: "crossOrigin",
  referrerpolicy: "referrerPolicy",
  contenteditable: "contentEditable",
  spellcheck: "spellCheck",
  datetime: "dateTime",
  formaction: "formAction",
  formenctype: "formEncType",
  formmethod: "formMethod",
  formnovalidate: "formNoValidate",
  formtarget: "formTarget",
  usemap: "useMap",
  srcset: "srcSet",
  tabindexindex: "tabIndex",
};

const NAMED_ENTITIES: Record<string, string> = {
  amp: "&",
  apos: "'",
  bull: "•",
  copy: "©",
  euro: "€",
  gt: ">",
  hellip: "…",
  ldquo: "“",
  larr: "←",
  lt: "<",
  mdash: "—",
  nbsp: " ",
  ndash: "–",
  pound: "£",
  quot: '"',
  rarr: "→",
  rdquo: "”",
  reg: "®",
  rsquo: "’",
  trade: "™",
  times: "×",
};

function decodeEntities(value: string): string {
  return value.replace(
    /&(#x[\da-f]+|#\d+|[a-z]+);/gi,
    (entity, reference: string) => {
      if (reference.startsWith("#x") || reference.startsWith("#X")) {
        const point = Number.parseInt(reference.slice(2), 16);
        return Number.isFinite(point) ? String.fromCodePoint(point) : entity;
      }
      if (reference.startsWith("#")) {
        const point = Number.parseInt(reference.slice(1), 10);
        return Number.isFinite(point) ? String.fromCodePoint(point) : entity;
      }
      return NAMED_ENTITIES[reference.toLowerCase()] ?? entity;
    },
  );
}

function parseAttributes(source: string): Record<string, string | true> {
  const attributes: Record<string, string | true> = {};
  const expression =
    /([^\s=/>]+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+)))?/g;
  let match: RegExpExecArray | null;

  while ((match = expression.exec(source))) {
    const name = match[1].toLowerCase();
    if (name.startsWith("on")) continue;

    const rawValue = match[2] ?? match[3] ?? match[4];
    if (rawValue === undefined && BOOLEAN_ATTRIBUTES.has(name)) {
      attributes[name] = true;
    } else if (rawValue !== undefined) {
      const value = decodeEntities(rawValue);
      if (name === "href" || name === "src" || name === "action" || name === "formaction") {
        const normalized = value.trim().toLowerCase();
        if (
          normalized.startsWith("javascript:") ||
          normalized.startsWith("data:") ||
          normalized.startsWith("vbscript:")
        ) {
          continue;
        }
      }
      attributes[name] = value;
    } else {
      attributes[name] = true;
    }
  }

  return attributes;
}

function parseHtmlFragment(source: string): HtmlNode[] {
  const root: HtmlNode & { type: "element"; tag: string } = {
    type: "element",
    tag: "root",
    attributes: {},
    children: [],
  };
  const stack = [root];
  const tokens = source.match(/<!--[\s\S]*?-->|<![^>]*>|<[^>]+>|[^<]+/g) ?? [];

  for (const token of tokens) {
    if (token.startsWith("<!--") || /^<!/i.test(token)) continue;

    if (/^<\//.test(token)) {
      const closingTag = token.match(/^<\/\s*([\w:-]+)/)?.[1]?.toLowerCase();
      if (!closingTag) continue;
      for (let index = stack.length - 1; index > 0; index -= 1) {
        if (stack[index].tag === closingTag) {
          stack.length = index;
          break;
        }
      }
      continue;
    }

    if (token.startsWith("<")) {
      const opening = token.match(/^<\s*([\w:-]+)([\s\S]*?)\/?\s*>$/);
      if (!opening) continue;
      const tag = opening[1].toLowerCase();
      if (tag === "script" || tag === "style") continue;
      const node: HtmlNode & { type: "element"; tag: string } = {
        type: "element",
        tag,
        attributes: parseAttributes(opening[2]),
        children: [],
      };
      stack[stack.length - 1].children.push(node);
      if (!VOID_ELEMENTS.has(tag) && !/\/\s*>$/.test(token)) stack.push(node);
      continue;
    }

    const value = decodeEntities(token);
    if (value) stack[stack.length - 1].children.push({ type: "text", value });
  }

  return root.children;
}

function parseStyle(value: string): Record<string, string> {
  const style: Record<string, string> = {};
  for (const declaration of value.split(";")) {
    const separator = declaration.indexOf(":");
    if (separator < 1) continue;
    const rawName = declaration.slice(0, separator).trim();
    const rawValue = declaration.slice(separator + 1).trim();
    if (!rawName || !rawValue) continue;
    const name = rawName.startsWith("--")
      ? rawName
      : rawName.replace(/-([a-z])/g, (_, letter: string) => letter.toUpperCase());
    style[name] = rawValue;
  }
  return style;
}

function renderNode(node: HtmlNode, key: string): ReactNode {
  if (node.type === "text") return node.value;

  const props: Record<string, unknown> = { key };
  for (const [name, value] of Object.entries(node.attributes)) {
    const reactName = ATTRIBUTE_NAMES[name] ?? name;
    if (name === "style" && typeof value === "string") {
      props.style = parseStyle(value);
    } else {
      props[reactName] = value === true && !BOOLEAN_ATTRIBUTES.has(name) ? "" : value;
    }
  }

  const children = node.children.map((child, index) =>
    renderNode(child, `${key}.${index}`),
  );
  return createElement(node.tag, props, ...children);
}

function renderNodes(nodes: HtmlNode[], prefix: string): ReactNode[] {
  return nodes.map((node, index) => renderNode(node, `${prefix}-${index}`));
}

function readV3Document() {
  const document = readFileSync(
    join(process.cwd(), "public", "web-temify-v3.html"),
    "utf8",
  );
  const stylesheet = document.match(/<style[^>]*>([\s\S]*?)<\/style>/i)?.[1];
  const body = document.match(/<body[^>]*>([\s\S]*?)<\/body>/i)?.[1];

  if (!stylesheet || !body) {
    throw new Error("The V3 homepage reference is missing its stylesheet or body.");
  }

  const withoutScripts = body.replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi, "");
  const nav = withoutScripts.match(/<nav\b[^>]*>[\s\S]*?<\/nav>/i)?.[0] ?? "";
  const withoutNav = nav ? withoutScripts.replace(nav, "") : withoutScripts;
  const footer = withoutNav.match(/<footer\b[^>]*>[\s\S]*?<\/footer>/i)?.[0] ?? "";
  const content = footer ? withoutNav.replace(footer, "") : withoutNav;

  return {
    stylesheet: `
      @import url("https://fonts.googleapis.com/css2?family=Cabinet+Grotesk:wght@400;500;700;800;900&family=Instrument+Serif:ital@0;1&display=swap");
      ${stylesheet}
      .v3-native-nav { display: contents; }
      .v3-skip-link { position: fixed; top: -5rem; left: 1rem; z-index: 1000; padding: .75rem 1rem; background: #ffd60a; color: #0f0d0a; border: 2px solid #0f0d0a; font-weight: 800; }
      .v3-skip-link:focus { top: 1rem; }
      .v3-native-home :where(a, button, input, [tabindex]) { scroll-margin-top: 6rem; }
      .v3-native-home a:focus-visible,
      .v3-native-home button:focus-visible,
      .v3-native-home input:focus-visible,
      .v3-native-home [tabindex]:focus-visible {
        outline: 3px solid #2358c4;
        outline-offset: 3px;
      }
      .v3-native-home .v3-feature-status {
        margin: .75rem auto 0;
        max-width: 520px;
        color: #ffd60a;
        font-size: .85rem;
        line-height: 1.5;
      }
      @media (prefers-reduced-motion: reduce) {
        .v3-native-home *, .v3-native-home *::before, .v3-native-home *::after {
          scroll-behavior: auto !important;
          animation-duration: .01ms !important;
          animation-iteration-count: 1 !important;
          transition-duration: .01ms !important;
        }
      }
    `,
    nav: parseHtmlFragment(nav),
    content: parseHtmlFragment(content),
    footer: parseHtmlFragment(footer),
  };
}

export default function V3Homepage() {
  const v3 = readV3Document();

  return (
    <>
      <style dangerouslySetInnerHTML={{ __html: v3.stylesheet }} />
      <a className="v3-skip-link" href="#main-content">
        Skip to content
      </a>
      <header className="v3-native-nav">{renderNodes(v3.nav, "nav")}</header>
      <main
        id="main-content"
        className="v3-native-home"
        aria-label="Web-Temify marketplace preview"
      >
        {renderNodes(v3.content, "content")}
      </main>
      {renderNodes(v3.footer, "footer")}
      <V3HomepageInteractions />
    </>
  );
}
