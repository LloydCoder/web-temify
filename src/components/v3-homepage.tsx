import { readFileSync } from "node:fs";
import { join } from "node:path";
import V3HomepageInteractions from "./v3-homepage-interactions";

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
  const nav = withoutScripts.match(/<nav\b[^>]*>[\s\S]*?<\/nav>/i)?.[0];
  const withoutNav = nav ? withoutScripts.replace(nav, "") : withoutScripts;
  const footer = withoutNav.match(/<footer\b[^>]*>[\s\S]*?<\/footer>/i)?.[0];
  const content = footer ? withoutNav.replace(footer, "") : withoutNav;

  return {
    stylesheet: `
      @import url("https://fonts.googleapis.com/css2?family=Cabinet+Grotesk:wght@400;500;700;800;900&family=Instrument+Serif:ital@0;1&display=swap");
      ${stylesheet}
      .v3-native-nav { display: contents; }
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
    nav: nav ?? "",
    content,
    footer: footer ?? "",
  };
}

export default function V3Homepage() {
  const v3 = readV3Document();

  return (
    <>
      <style dangerouslySetInnerHTML={{ __html: v3.stylesheet }} />
      <header
        className="v3-native-nav"
        dangerouslySetInnerHTML={{ __html: v3.nav }}
      />
      <main
        id="main-content"
        className="v3-native-home"
        aria-label="Web-Temify marketplace preview"
        dangerouslySetInnerHTML={{ __html: v3.content }}
      />
      {v3.footer ? <footer dangerouslySetInnerHTML={{ __html: v3.footer }} /> : null}
      <V3HomepageInteractions />
    </>
  );
}
