import Link from "next/link";
import { notFound } from "next/navigation";
import "./ecosystem-destination.css";

type AreaKey =
  | "hosting"
  | "ai-site-builder"
  | "directory"
  | "automations"
  | "specialists"
  | "implementation"
  | "platform"
  | "tech-hub";

const areas: Record<
  AreaKey,
  {
    number: string;
    title: string;
    status: string;
    summary: string;
    available: string[];
    planned: string[];
    nextStep: string;
  }
> = {
  hosting: {
    number: "02",
    title: "Web Hosting & Deployment",
    status: "Planned · provisioning not operational",
    summary:
      "A future home for hosting, deployment, domains, SSL, and site operations connected to Web-Temify products.",
    available: [
      "This page documents the intended service scope only.",
      "No hosting plan can be purchased or provisioned from this page.",
    ],
    planned: [
      "Hosting plan catalogue and transparent limits",
      "Automated deployments, domain connection and SSL lifecycle",
      "Usage visibility, backups, incident handling and support workflows",
    ],
    nextStep: "Browse the existing catalogue while hosting is in development.",
  },
  "ai-site-builder": {
    number: "03",
    title: "AI Site Builder",
    status: "Planned · generation disabled",
    summary:
      "The planned builder will turn a brief into an editable website workflow. No generation or deployment is available on this page.",
    available: [
      "The homepage prompt field is a non-generating concept preview.",
      "No code, website, or deployment is produced by submitting a prompt.",
    ],
    planned: [
      "Brief intake and explicit requirements",
      "Reviewable generation with editable output",
      "Preview, export and deployment only after security and quality checks",
    ],
    nextStep: "Browse templates as a currently available alternative.",
  },
  directory: {
    number: "04",
    title: "Tech Directory Hub",
    status: "Preview · submissions and paid placements not live",
    summary:
      "A curated discovery layer for external tools and services. The homepage currently contains a limited illustrative directory preview.",
    available: [
      "Some homepage entries link to their official external websites.",
      "Web-Temify does not verify vendor performance or endorse external services merely by listing them.",
    ],
    planned: [
      "Searchable categories and reviewed listings",
      "Supplier submission, moderation and correction workflows",
      "Sponsored placements with clear labels and advertising disclosures",
    ],
    nextStep: "Return to the homepage to explore the current preview.",
  },
  automations: {
    number: "05",
    title: "Verified Automation Marketplace",
    status: "Planned · transactions disabled",
    summary:
      "A future marketplace for discoverable, reviewed automations with clear permissions, compatibility and operational boundaries.",
    available: [
      "No automation can currently be purchased, installed, or run through this destination.",
    ],
    planned: [
      "Publisher identity and artifact provenance",
      "Permission and risk disclosures with versioned verification evidence",
      "Installation, update, rollback and support lifecycle",
    ],
    nextStep: "Explore the catalogue for current digital-product discovery.",
  },
  specialists: {
    number: "06",
    title: "Specialist Supplier Directory",
    status: "Planned · onboarding not available",
    summary:
      "A future directory for specialist technology suppliers, with transparent capabilities and evidence-backed profiles.",
    available: [
      "No supplier registration, verification, or marketplace enquiry is enabled here.",
    ],
    planned: [
      "Supplier onboarding and identity checks",
      "Capability profiles, evidence review and moderation",
      "Enquiry routing, service standards and appeal handling",
    ],
    nextStep: "For independent engineering services, visit Tinlance directly.",
  },
  implementation: {
    number: "07",
    title: "Outcome-Based AI Implementation",
    status: "Planned · contracts and milestone payments disabled",
    summary:
      "A future workflow for scoped AI implementation engagements with measurable outcomes and explicit acceptance criteria.",
    available: [
      "This page does not create a contract, collect funds, or initiate a delivery engagement.",
    ],
    planned: [
      "Structured scope, deliverables and acceptance criteria",
      "Milestone review, change control and dispute workflows",
      "Payments only after provider, accounting, legal and operational gates are verified",
    ],
    nextStep:
      "For existing consulting services, contact Tinlance outside this marketplace.",
  },
  platform: {
    number: "08",
    title: "Shared Enterprise Platform",
    status: "Shared technical foundation · feature availability varies",
    summary:
      "The cross-cutting architecture for identity, authorization, policy, approvals, auditability and operational controls. It is a foundation, not a standalone marketplace.",
    available: [
      "Repository code and green CI are not proof that every feature is deployed or enabled in production.",
      "Production payment processing, payouts, settlement posting and live money movement remain gated.",
    ],
    planned: [
      "Consistent identity and authorization boundaries across product areas",
      "Evidence-backed approvals, audit trails and operational monitoring",
      "Release gates tied to security, legal, provider and support readiness",
    ],
    nextStep:
      "Review the current catalogue or return to the ecosystem overview.",
  },
  "tech-hub": {
    number: "09",
    title: "Tech Hub & Advertising Engine",
    status: "Planned · publishing and monetization not enabled",
    summary:
      "A future editorial and audience layer for useful technical content, search discovery and transparent advertising inventory.",
    available: [
      "The homepage newsletter interface does not prove a working subscription backend.",
      "No paid placements, affiliate tracking or sponsored newsletter inventory is offered here.",
    ],
    planned: [
      "Editorial publishing, authoring and content review",
      "SEO metadata, structured content and performance measurement",
      "Clearly labelled ads, affiliate disclosures and sponsorship inventory",
    ],
    nextStep: "Explore the current homepage and product catalogue.",
  },
};

export function generateStaticParams() {
  return Object.keys(areas).map((area) => ({ area }));
}

export default async function EcosystemDestination({ area }: { area: string }) {
  if (!(area in areas)) notFound();
  const item = areas[area as AreaKey];
  return (
    <main className="ecosystem-destination">
      <div className="ecosystem-destination-top">
        <Link href="/" className="ecosystem-wordmark">
          Web-Temify<span aria-hidden="true">.</span>
        </Link>
        <Link href="/#ecosystem" className="ecosystem-back">
          ← All ecosystem areas
        </Link>
      </div>
      <section
        className="ecosystem-destination-hero"
        aria-labelledby="destination-title"
      >
        <p className="ecosystem-destination-number">
          AREA {item.number} / WEB-TEMIFY ECOSYSTEM
        </p>
        <p className="ecosystem-destination-status">{item.status}</p>
        <h1 id="destination-title">{item.title}</h1>
        <p className="ecosystem-destination-summary">{item.summary}</p>
        <p className="ecosystem-destination-disclaimer">
          Availability notice: this destination describes verified current scope
          and planned work. It does not activate features that are not
          operational.
        </p>
      </section>
      <div className="ecosystem-destination-columns">
        <section
          className="ecosystem-destination-panel"
          aria-labelledby="available-title"
        >
          <p className="ecosystem-destination-kicker">CURRENT STATE</p>
          <h2 id="available-title">What is available today</h2>
          <ul>
            {item.available.map((line) => (
              <li key={line}>{line}</li>
            ))}
          </ul>
        </section>
        <section
          className="ecosystem-destination-panel ecosystem-destination-planned"
          aria-labelledby="planned-title"
        >
          <p className="ecosystem-destination-kicker">ROADMAP</p>
          <h2 id="planned-title">What this area is intended to support</h2>
          <ul>
            {item.planned.map((line) => (
              <li key={line}>{line}</li>
            ))}
          </ul>
        </section>
      </div>
      <section className="ecosystem-destination-next">
        <h2>Build with what is available</h2>
        <p>{item.nextStep}</p>
        <div className="ecosystem-destination-actions">
          <Link href="/catalog" className="ecosystem-destination-button">
            Browse catalogue →
          </Link>
          <Link href="/#ecosystem" className="ecosystem-destination-secondary">
            Back to all nine areas
          </Link>
          {area === "specialists" || area === "implementation" ? (
            <a
              href="https://tinlance.com"
              rel="noopener noreferrer"
              target="_blank"
              className="ecosystem-destination-secondary"
            >
              Tinlance website ↗
            </a>
          ) : null}
        </div>
      </section>
      <footer className="ecosystem-destination-footer">
        Web-Temify LTD · Capability availability is stated explicitly; planned
        services are not represented as live.
      </footer>
    </main>
  );
}
