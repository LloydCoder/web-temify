"use client";

import Link from "next/link";
import { useEffect, useRef, useState } from "react";
import "./v3-home.css";

const directoryFilters: Record<string, string[]> = {
  "All Tools": [],
  "AI & ML": ["ai", "ml", "coding", "assistant"],
  "Web3 & Blockchain": ["web3", "blockchain", "crypto", "nft", "wallet"],
  "Hosting & Infra": ["hosting", "infra", "cloud", "deploy"],
  "Design Tools": ["design", "creative", "ui", "ux"],
  "No-Code": ["no", "code", "nocode", "builder"],
  "Dev Tools": ["dev", "coding", "developer", "api", "git"],
  "Freelancer Resources": ["freelancer", "resources", "client", "invoice"],
};

export default function HomePage() {
  const rootRef = useRef<HTMLDivElement>(null);
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
  const [activeDirectory, setActiveDirectory] = useState("All Tools");

  useEffect(() => {
    const root = rootRef.current;
    if (!root) return;
    const revealItems = root.querySelectorAll<HTMLElement>(".reveal");
    if (
      "IntersectionObserver" in window &&
      !window.matchMedia("(prefers-reduced-motion: reduce)").matches
    ) {
      const observer = new IntersectionObserver(
        (entries) => {
          entries.forEach((entry, index) => {
            if (!entry.isIntersecting) return;
            const target = entry.target as HTMLElement;
            target.style.transitionDelay = `${Math.min(index, 8) * 35}ms`;
            target.classList.add("visible");
            observer.unobserve(target);
          });
        },
        { threshold: 0.08 },
      );
      revealItems.forEach((item) => observer.observe(item));
      return () => observer.disconnect();
    }
    revealItems.forEach((item) => item.classList.add("visible"));
  }, []);

  useEffect(() => {
    const root = rootRef.current;
    if (!root) return;
    const allowed = directoryFilters[activeDirectory] ?? [];
    root.querySelectorAll<HTMLElement>(".dir-card").forEach((card) => {
      const tags = (card.dataset.directory ?? "").toLowerCase().split(/\s+/);
      card.hidden =
        allowed.length > 0 &&
        !allowed.some((filter) => tags.some((tag) => tag.includes(filter)));
    });
    root.querySelectorAll<HTMLButtonElement>(".dir-tab").forEach((tab) => {
      const selected = tab.textContent?.trim() === activeDirectory;
      tab.classList.toggle("active", selected);
      tab.setAttribute("aria-pressed", String(selected));
    });
  }, [activeDirectory]);

  useEffect(() => {
    const root = rootRef.current;
    if (!root) return;
    const input = root.querySelector<HTMLInputElement>(".ai-input");
    const chips = root.querySelectorAll<HTMLElement>(".ai-chip");
    const handlers = new Map<HTMLElement, () => void>();
    const keyboardHandlers = new Map<
      HTMLElement,
      (event: KeyboardEvent) => void
    >();
    chips.forEach((chip) => {
      const activate = () => {
        if (!input) return;
        input.value = `${chip.textContent?.trim() ?? ""} website`;
        input.focus();
      };
      const clickHandler = () => activate();
      const keyHandler = (event: KeyboardEvent) => {
        if (event.key === "Enter" || event.key === " ") {
          event.preventDefault();
          activate();
        }
      };
      handlers.set(chip, clickHandler);
      keyboardHandlers.set(chip, keyHandler);
      chip.addEventListener("click", clickHandler);
      chip.addEventListener("keydown", keyHandler);
      chip.setAttribute("role", "button");
      chip.setAttribute("tabindex", "0");
      chip.setAttribute(
        "aria-label",
        `Use ${chip.textContent?.trim() ?? "suggestion"} prompt`,
      );
    });
    return () => {
      handlers.forEach((handler, chip) =>
        chip.removeEventListener("click", handler),
      );
      keyboardHandlers.forEach((handler, chip) =>
        chip.removeEventListener("keydown", handler),
      );
    };
  }, []);

  return (
    <div className="v3-app" ref={rootRef}>
      <a className="skip-link" href="#main-content">
        Skip to main content
      </a>
      <nav>
        <Link href="/" className="logo">
          Web-Temify <span className="logo-dot"></span>
        </Link>
        <ul
          className={`nav-links${mobileMenuOpen ? " is-open" : ""}`}
          id="primary-navigation"
          onClick={() => setMobileMenuOpen(false)}
        >
          <li>
            <a href="#templates">Templates</a>
          </li>
          <li>
            <a href="#templates">Scripts</a>
          </li>
          <li className="nav-new">
            <a href="#kits">Launch Kits</a>
          </li>
          <li>
            <a href="#web3">Web3</a>
          </li>
          <li>
            <a href="#directory">Directory</a>
          </li>
          <li>
            <a href="#services">Services</a>
          </li>
          <li>
            <a href="#pricing">Pricing</a>
          </li>
        </ul>
        <button
          className="mobile-menu-toggle"
          type="button"
          aria-label="Toggle navigation"
          aria-controls="primary-navigation"
          aria-expanded={mobileMenuOpen}
          onClick={() => setMobileMenuOpen((open) => !open)}
        >
          <span />
          <span />
          <span />
        </button>
        <div className="nav-actions">
          <span
            className="btn btn-ghost"
            aria-disabled="true"
            title="Account access is not live yet"
          >
            Account access soon
          </span>
          <a href="#templates" className="btn btn-fill">
            Browse Templates →
          </a>
        </div>
      </nav>
      <main
        id="main-content"
        className="v3-main"
        aria-label="Web-Temify marketplace preview"
      >
        <section className="hero">
          <div className="hero-bg-shape shape-1"></div>
          <div className="hero-bg-shape shape-2"></div>
          <div className="hero-bg-shape shape-3"></div>

          <div className="hero-left">
            <div className="hero-badge">Marketplace Preview</div>
            <h1>
              Your website,
              <br />
              <span className="serif">ready in</span>
              <br />
              minutes.
            </h1>
            <p className="hero-desc">
              Explore the Web-Temify marketplace concept: templates, launch
              kits, scripts, and tools for builders. The catalogue, seller
              features, and checkout are not live yet; no products are available
              for purchase.
            </p>
            <div className="hero-cta">
              <a href="#templates" className="btn btn-fill btn-big">
                Browse Templates
              </a>
              <a href="#how" className="btn btn-ghost btn-big">
                See how it works
              </a>
            </div>
            <div className="hero-trust">
              <div className="trust-faces">
                <div className="face f1">😊</div>
                <div className="face f2">🙂</div>
                <div className="face f3">😄</div>
                <div className="face f4">🤩</div>
              </div>
              <div className="trust-text">
                <strong>Built for builders</strong>
                <br />
                marketplace preview
              </div>
            </div>
          </div>

          <div className="hero-right">
            <div className="preview-card">
              <div className="card-header">
                <span className="dot dot-r"></span>
                <span className="dot dot-y"></span>
                <span className="dot dot-g"></span>  NeoBank Pro Template
              </div>
              <div className="card-body cb-1">
                <h4>🏦 NeoBank Pro</h4>
                <p>
                  Illustrative fintech template concept. Not currently available
                  for purchase.
                </p>
                <div style={{ marginTop: "0.8rem" }}>
                  <div
                    className="mock-bar"
                    style={{ background: "#ff5733", width: "70%" }}
                  ></div>
                  <div
                    className="mock-bar"
                    style={{ background: "#ffd60a", width: "45%" }}
                  ></div>
                  <div
                    className="mock-bar"
                    style={{ background: "#0f0d0a22", width: "90%" }}
                  ></div>
                </div>
                <span className="card-tag" style={{ background: "#fff5f0" }}>
                  Fintech · Preview
                </span>
              </div>
            </div>
            <div className="preview-card">
              <div className="card-header">
                <span className="dot dot-r"></span>
                <span className="dot dot-y"></span>
                <span className="dot dot-g"></span>  Web3 DApp Kit
              </div>
              <div className="card-body cb-2">
                <h4>⛓️ DApp Kit</h4>
                <p>Wallet connect, NFT gallery, smart contract UI.</p>
                <div style={{ marginTop: "0.8rem" }}>
                  <div
                    className="mock-block"
                    style={{ background: "#4f8ef733" }}
                  ></div>
                  <div
                    className="mock-bar"
                    style={{ background: "#4f8ef7", width: "60%" }}
                  ></div>
                </div>
                <span className="card-tag" style={{ background: "#f0f8ff" }}>
                  Web3 · Preview
                </span>
              </div>
            </div>
            <div className="preview-card">
              <div className="card-header">
                <span className="dot dot-r"></span>
                <span className="dot dot-y"></span>
                <span className="dot dot-g"></span>  P2P Trading Script
              </div>
              <div className="card-body cb-3">
                <h4>💱 P2P Script</h4>
                <p>
                  Illustrative P2P trading UI concept; no trading or escrow
                  service is offered.
                </p>
                <div style={{ marginTop: "0.8rem" }}>
                  <div
                    className="mock-block"
                    style={{ background: "#c084fc44" }}
                  ></div>
                  <div
                    className="mock-bar"
                    style={{ background: "#c084fc", width: "50%" }}
                  ></div>
                </div>
                <span className="card-tag" style={{ background: "#f5f0ff" }}>
                  Script · Preview
                </span>
              </div>
            </div>
          </div>
        </section>

        <div className="strip">
          <div className="strip-inner">
            Website Templates <span>✦</span> Banking Scripts <span>✦</span> Web3
            DApp Kits <span>✦</span> NFT Marketplace <span>✦</span> Courier
            Templates <span>✦</span> P2P Crypto Scripts <span>✦</span> Loan
            Management <span>✦</span> AI Page Generator <span>✦</span> Tech
            Directory <span>✦</span> Payment providers pending verification
            <span>✦</span> Website Templates <span>✦</span> Banking Scripts
            <span>✦</span> Web3 DApp Kits <span>✦</span> NFT Marketplace
            <span>✦</span> Courier Templates <span>✦</span> P2P Crypto Scripts
            <span>✦</span> Loan Management <span>✦</span> AI Page Generator
            <span>✦</span> Tech Directory <span>✦</span> Paystack · Stripe ·
            LemonSqueezy <span>✦</span>
          </div>
        </div>

        <section id="templates">
          <div className="section-head reveal">
            <div>
              <p className="eyebrow">Browse by Category</p>
              <h2 className="section-title">
                Whatever your
                <br />
                <span className="serif">business needs</span>
              </h2>
            </div>
            <Link href="/catalog" className="btn btn-ghost">
              Browse catalogue →
            </Link>
          </div>
          <div className="cat-grid reveal">
            <div className="cat-card cc-1">
              <span className="cat-count">Preview</span>
              <span className="cat-emoji">🏦</span>
              <h3>Fintech & Banking</h3>
              <p>
                Banking UIs, loan platforms, and payment system templates for
                the African market.
              </p>
            </div>
            <div className="cat-card cc-2">
              <span className="cat-count">Preview</span>
              <span className="cat-emoji">⛓️</span>
              <h3>Web3 & Blockchain</h3>
              <p>
                NFT marketplaces, DeFi dashboards, DAO governance, and wallet UI
                kits.
              </p>
            </div>
            <div className="cat-card cc-3">
              <span className="cat-count">Preview</span>
              <span className="cat-emoji">🚚</span>
              <h3>Logistics & Courier</h3>
              <p>
                Delivery company sites with rate calculators, tracking UI, and
                fleet management.
              </p>
            </div>
            <div className="cat-card cc-4">
              <span className="cat-count">Preview</span>
              <span className="cat-emoji">🚀</span>
              <h3>SaaS & Startups</h3>
              <p>
                Modern landing pages, app showcases, and product-led growth
                templates.
              </p>
            </div>
            <div className="cat-card cc-5">
              <span className="cat-count">Preview</span>
              <span className="cat-emoji">🎨</span>
              <h3>Agency & Portfolio</h3>
              <p>
                Bold, conversion-focused designs for creative agencies and
                freelancers.
              </p>
            </div>
            <div className="cat-card cc-6">
              <span className="cat-count">Preview</span>
              <span className="cat-emoji">🛒</span>
              <h3>E-commerce</h3>
              <p>
                Ready-to-sell storefronts for digital products, subscriptions,
                and physical goods.
              </p>
            </div>
            <div className="cat-card cc-7">
              <span className="cat-count">Preview</span>
              <span className="cat-emoji">🏘️</span>
              <h3>Real Estate</h3>
              <p>
                Property listing, agent profiles, and developer portfolio
                templates.
              </p>
            </div>
            <div className="cat-card cc-8">
              <span className="cat-count">Preview</span>
              <span className="cat-emoji">⚡</span>
              <h3>Scripts & Tools</h3>
              <p>
                Full-stack functional scripts — P2P trading, loan management,
                banking, POS, and more.
              </p>
            </div>
          </div>
        </section>

        <section className="section-alt" id="featured">
          <div className="section-head reveal">
            <div>
              <p className="eyebrow">Featured Products</p>
              <h2 className="section-title">
                Template & script concepts
                <br />
                <span className="serif">& scripts</span>
              </h2>
            </div>
            <Link href="/catalog" className="btn btn-ghost">
              Browse catalogue →
            </Link>
          </div>
          <div className="templates-grid reveal">
            <div className="tpl-card">
              <div className="tpl-preview" style={{ background: "#fff5f0" }}>
                <span className="tpl-badge badge-hot">🔥 Hot</span>🏦
              </div>
              <div className="tpl-body">
                <div className="tpl-name">NeoBank Pro Template</div>
                <div className="tpl-type">HTML5 + React · 12 pages</div>
                <div className="tpl-footer">
                  <span className="tpl-price">Preview</span>
                  <span className="tpl-stats">
                    Preview only · Not available
                  </span>
                </div>
              </div>
            </div>
            <div className="tpl-card">
              <div className="tpl-preview" style={{ background: "#f0f8ff" }}>
                <span className="tpl-badge badge-web3">Web3</span>⛓️
              </div>
              <div className="tpl-body">
                <div className="tpl-name">NFT Marketplace UI Kit</div>
                <div className="tpl-type">Next.js 15 · 18 pages</div>
                <div className="tpl-footer">
                  <span className="tpl-price">Preview</span>
                  <span className="tpl-stats">
                    Preview only · Not available
                  </span>
                </div>
              </div>
            </div>
            <div className="tpl-card">
              <div className="tpl-preview" style={{ background: "#fff8e1" }}>
                <span className="tpl-badge badge-new">✨ New</span>🚚
              </div>
              <div className="tpl-body">
                <div className="tpl-name">Courier & Logistics Pro</div>
                <div className="tpl-type">WordPress · Elementor · 10 pages</div>
                <div className="tpl-footer">
                  <span className="tpl-price">Preview</span>
                  <span className="tpl-stats">
                    Preview only · Not available
                  </span>
                </div>
              </div>
            </div>
            <div className="tpl-card">
              <div className="tpl-preview" style={{ background: "#f5f0ff" }}>
                <span className="tpl-badge badge-hot">🔥 Hot</span>💱
              </div>
              <div className="tpl-body">
                <div className="tpl-name">P2P Trading Script</div>
                <div className="tpl-type">PHP + Laravel · Full script</div>
                <div className="tpl-footer">
                  <span className="tpl-price">Preview</span>
                  <span className="tpl-stats">
                    Preview only · Not available
                  </span>
                </div>
              </div>
            </div>
            <div className="tpl-card">
              <div className="tpl-preview" style={{ background: "#f0fff8" }}>
                <span className="tpl-badge badge-new">✨ New</span>🏘️
              </div>
              <div className="tpl-body">
                <div className="tpl-name">Real Estate Listings Pro</div>
                <div className="tpl-type">Next.js + Supabase · 14 pages</div>
                <div className="tpl-footer">
                  <span className="tpl-price">Preview</span>
                  <span className="tpl-stats">
                    Preview only · Not available
                  </span>
                </div>
              </div>
            </div>
            <div className="tpl-card">
              <div className="tpl-preview" style={{ background: "#fff5f0" }}>
                <span className="tpl-badge badge-top">⭐ Top</span>💰
              </div>
              <div className="tpl-body">
                <div className="tpl-name">Loan Management System</div>
                <div className="tpl-type">PHP + MySQL · Full script</div>
                <div className="tpl-footer">
                  <span className="tpl-price">Preview</span>
                  <span className="tpl-stats">
                    Preview only · Not available
                  </span>
                </div>
              </div>
            </div>
          </div>
        </section>

        <section id="kits">
          <div className="section-head reveal">
            <div>
              <p className="eyebrow">Launch Kits</p>
              <h2 className="section-title">
                Complete systems,
                <br />
                <span className="serif">not just templates</span>
              </h2>
              <p
                style={{
                  fontSize: "0.9rem",
                  color: "var(--muted)",
                  marginTop: "0.75rem",
                  fontWeight: "500",
                  maxWidth: "400px",
                }}
              >
                Everything bundled, tested, and ready to deploy — not just a
                single file.
              </p>
            </div>
          </div>
          <div className="kits-grid reveal">
            <div className="kit-card dark">
              <div className="kit-watermark">🚀</div>
              <div className="kit-tag">⚡ Most Popular</div>
              <div className="kit-name">SaaS Starter Kit</div>
              <div className="kit-desc">
                Launch a SaaS product in a weekend — auth, billing, dashboard,
                onboarding, and landing page, all included.
              </div>
              <div className="kit-items">
                <span className="kit-item">Landing Page</span>
                <span className="kit-item">Auth System</span>
                <span className="kit-item">Dashboard UI</span>
                <span className="kit-item">Stripe Billing</span>
                <span className="kit-item">Admin Panel</span>
              </div>
              <div className="kit-footer">
                <div>
                  <span
                    className="kit-price"
                    style={{ color: "var(--yellow)" }}
                  >
                    Preview
                  </span>
                </div>
                <Link href="/catalog" className="btn btn-yellow">
                  Browse catalogue →
                </Link>
              </div>
            </div>
            <div className="kit-card">
              <div className="kit-watermark">⛓️</div>
              <div className="kit-tag">🔥 Web3</div>
              <div className="kit-name">Web3 DApp Starter Kit</div>
              <div className="kit-desc">
                Wallet connect, smart contract UI, token dashboard, and NFT
                components — launch your dApp without starting from scratch.
              </div>
              <div className="kit-items">
                <span className="kit-item">Wallet Connect</span>
                <span className="kit-item">Smart Contract UI</span>
                <span className="kit-item">NFT Gallery</span>
                <span className="kit-item">DAO Governance</span>
                <span className="kit-item">Mint Page</span>
              </div>
              <div className="kit-footer">
                <div>
                  <span className="kit-price">Preview</span>
                </div>
                <Link href="/catalog" className="btn btn-fill">
                  Browse catalogue →
                </Link>
              </div>
            </div>
            <div className="kit-card">
              <div className="kit-watermark">🏦</div>
              <div className="kit-tag">💰 Fintech</div>
              <div className="kit-name">Fintech Launch Kit</div>
              <div className="kit-desc">
                Banking UI, loan calculator, KYC flow, Paystack integration, and
                compliance pages. Africa-ready from day one.
              </div>
              <div className="kit-items">
                <span className="kit-item">Banking Template</span>
                <span className="kit-item">Loan Calculator</span>
                <span className="kit-item">KYC Flow</span>
                <span className="kit-item">Paystack Ready</span>
                <span className="kit-item">Admin Dashboard</span>
              </div>
              <div className="kit-footer">
                <div>
                  <span className="kit-price">Preview</span>
                </div>
                <Link href="/catalog" className="btn btn-fill">
                  Browse catalogue →
                </Link>
              </div>
            </div>
            <div className="kit-card">
              <div className="kit-watermark">🎨</div>
              <div className="kit-tag">🏢 Agency</div>
              <div className="kit-name">Agency Starter Kit</div>
              <div className="kit-desc">
                Portfolio, services pages, case studies, contact forms, and lead
                capture — everything an agency needs to launch.
              </div>
              <div className="kit-items">
                <span className="kit-item">Portfolio Pages</span>
                <span className="kit-item">Services Layout</span>
                <span className="kit-item">Case Studies</span>
                <span className="kit-item">Lead Forms</span>
                <span className="kit-item">Blog Engine</span>
              </div>
              <div className="kit-footer">
                <div>
                  <span className="kit-price">Preview</span>
                </div>
                <Link href="/catalog" className="btn btn-fill">
                  Browse catalogue →
                </Link>
              </div>
            </div>
          </div>
        </section>

        <section>
          <div className="ai-box reveal">
            <p className="eyebrow">AI-Powered</p>
            <h2
              className="section-title"
              style={{ textAlign: "center", margin: "0 auto 0.75rem" }}
            >
              AI Site Builder
              <br />
              <span className="serif">coming soon</span>
            </h2>
            <p className="ai-sub">
              The AI Site Builder is planned, but generation is not available
              yet. Explore the concept with the prompt suggestions below.
            </p>
            <div className="ai-input-row">
              <input
                type="text"
                className="ai-input"
                placeholder="e.g. A fintech app for Nigerian SMEs..."
              />
              <button
                className="btn btn-yellow"
                type="button"
                disabled
                aria-describedby="ai-builder-status"
              >
                Coming soon
              </button>
              <p
                id="ai-builder-status"
                className="ai-builder-status"
                role="status"
              >
                AI generation is not live yet.
              </p>
            </div>
            <div className="ai-chips">
              <span className="ai-chip">Logistics company</span>
              <span className="ai-chip">NFT marketplace</span>
              <span className="ai-chip">Loan app Nigeria</span>
              <span className="ai-chip">SaaS dashboard</span>
              <span className="ai-chip">Crypto exchange</span>
              <span className="ai-chip">Real estate agency</span>
            </div>
          </div>
        </section>

        <section className="section-alt" id="web3">
          <div className="section-head reveal">
            <div>
              <p className="eyebrow">Web3 Hub</p>
              <h2 className="section-title">
                Build the decentralised
                <br />
                <span className="serif">web faster</span>
              </h2>
              <p
                style={{
                  fontSize: "0.9rem",
                  color: "var(--muted)",
                  marginTop: "0.75rem",
                  fontWeight: "500",
                }}
              >
                Components, kits, and scripts for the next generation of the
                internet.
              </p>
            </div>
            <Link href="/catalog" className="btn btn-ghost">
              Browse catalogue →
            </Link>
          </div>
          <div className="web3-grid reveal">
            <div className="web3-card">
              <span className="web3-icon">👛</span>
              <div className="web3-name">Wallet Auth UI</div>
              <div className="web3-desc">
                MetaMask, WalletConnect, Coinbase — ready-made connection flows
                for any project
              </div>
            </div>
            <div className="web3-card">
              <span className="web3-icon">🖼️</span>
              <div className="web3-name">NFT Galleries</div>
              <div className="web3-desc">
                Collection displays, mint pages, and auction interfaces built
                and tested
              </div>
            </div>
            <div className="web3-card">
              <span className="web3-icon">📊</span>
              <div className="web3-name">DeFi Dashboards</div>
              <div className="web3-desc">
                Staking, liquidity pools, and yield farming — complete UI kits
                ready to download
              </div>
            </div>
            <div className="web3-card">
              <span className="web3-icon">🏛️</span>
              <div className="web3-name">DAO Governance</div>
              <div className="web3-desc">
                Proposal voting, treasury management, and member portals for
                your community
              </div>
            </div>
          </div>
        </section>

        <section id="directory">
          <div className="section-head reveal">
            <div>
              <p className="eyebrow">Tech Directory</p>
              <h2 className="section-title">
                Curated tools
                <br />
                <span className="serif">for builders</span>
              </h2>
              <p
                style={{
                  fontSize: "0.9rem",
                  color: "var(--muted)",
                  marginTop: "0.75rem",
                  fontWeight: "500",
                  maxWidth: "400px",
                }}
              >
                Explore selected external tools. Directory submissions and
                featured listings are not available yet.
              </p>
            </div>
            <Link href="/catalog" className="btn btn-ghost">
              Browse catalogue →
            </Link>
          </div>
          <div className="dir-tabs reveal">
            <button
              className="dir-tab active"
              type="button"
              onClick={() => setActiveDirectory("All Tools")}
            >
              All Tools
            </button>
            <button
              className="dir-tab"
              type="button"
              onClick={() => setActiveDirectory("AI & ML")}
            >
              AI & ML
            </button>
            <button
              className="dir-tab"
              type="button"
              onClick={() => setActiveDirectory("Web3 & Blockchain")}
            >
              Web3 & Blockchain
            </button>
            <button
              className="dir-tab"
              type="button"
              onClick={() => setActiveDirectory("Hosting & Infra")}
            >
              Hosting & Infra
            </button>
            <button
              className="dir-tab"
              type="button"
              onClick={() => setActiveDirectory("Design Tools")}
            >
              Design Tools
            </button>
            <button
              className="dir-tab"
              type="button"
              onClick={() => setActiveDirectory("No-Code")}
            >
              No-Code
            </button>
            <button
              className="dir-tab"
              type="button"
              onClick={() => setActiveDirectory("Dev Tools")}
            >
              Dev Tools
            </button>
            <button
              className="dir-tab"
              type="button"
              onClick={() => setActiveDirectory("Freelancer Resources")}
            >
              Freelancer Resources
            </button>
          </div>
          <div className="dir-grid reveal">
            <a
              className="dir-card featured"
              href="https://claude.ai/"
              target="_blank"
              rel="noreferrer"
              data-directory="ai coding free tier"
            >
              <div className="dir-logo">🤖</div>
              <div className="dir-info">
                <div className="dir-name">
                  Claude by Anthropic <span className="star">★ Featured</span>
                </div>
                <div className="dir-desc">
                  Most capable AI assistant for coding, writing, and complex
                  analysis tasks
                </div>
                <div className="dir-pills">
                  <span className="dir-pill">AI</span>
                  <span className="dir-pill">Coding</span>
                  <span className="dir-pill">Free tier</span>
                </div>
              </div>
            </a>
            <a
              className="dir-card featured"
              href="https://vercel.com/"
              target="_blank"
              rel="noreferrer"
              data-directory="hosting ci cd free tier"
            >
              <div className="dir-logo">▲</div>
              <div className="dir-info">
                <div className="dir-name">
                  Vercel <span className="star">★ Featured</span>
                </div>
                <div className="dir-desc">
                  Deploy web projects instantly — the fastest frontend cloud
                  platform available
                </div>
                <div className="dir-pills">
                  <span className="dir-pill">Hosting</span>
                  <span className="dir-pill">CI/CD</span>
                  <span className="dir-pill">Free tier</span>
                </div>
              </div>
            </a>
            <a
              className="dir-card"
              href="https://supabase.com/"
              target="_blank"
              rel="noreferrer"
              data-directory="database baas free tier"
            >
              <div className="dir-logo">🔷</div>
              <div className="dir-info">
                <div className="dir-name">Supabase</div>
                <div className="dir-desc">
                  Open source Firebase alternative — Postgres, auth, storage,
                  and edge functions
                </div>
                <div className="dir-pills">
                  <span className="dir-pill">Database</span>
                  <span className="dir-pill">BaaS</span>
                  <span className="dir-pill">Free tier</span>
                </div>
              </div>
            </a>
            <a
              className="dir-card"
              href="https://hardhat.org/"
              target="_blank"
              rel="noreferrer"
              data-directory="web3 ethereum free"
            >
              <div className="dir-logo">🔥</div>
              <div className="dir-info">
                <div className="dir-name">Hardhat</div>
                <div className="dir-desc">
                  Ethereum development environment for smart contract testing
                  and deployment
                </div>
                <div className="dir-pills">
                  <span className="dir-pill">Web3</span>
                  <span className="dir-pill">Ethereum</span>
                  <span className="dir-pill">Free</span>
                </div>
              </div>
            </a>
            <a
              className="dir-card"
              href="https://paystack.com/"
              target="_blank"
              rel="noreferrer"
              data-directory="payments nigeria africa"
            >
              <div className="dir-logo">💳</div>
              <div className="dir-info">
                <div className="dir-name">Paystack</div>
                <div className="dir-desc">
                  Payment infrastructure for businesses, including cards, bank transfers, USSD, and mobile money.
                </div>
                <div className="dir-pills">
                  <span className="dir-pill">Payments</span>
                  <span className="dir-pill">Nigeria</span>
                  <span className="dir-pill">Africa</span>
                </div>
              </div>
            </a>
            <a
              className="dir-card"
              href="https://figma.com/"
              target="_blank"
              rel="noreferrer"
              data-directory="design ui ux free tier"
            >
              <div className="dir-logo">🎨</div>
              <div className="dir-info">
                <div className="dir-name">Figma</div>
                <div className="dir-desc">
                  Collaborative UI/UX design tool used by millions of teams
                  worldwide
                </div>
                <div className="dir-pills">
                  <span className="dir-pill">Design</span>
                  <span className="dir-pill">UI/UX</span>
                  <span className="dir-pill">Free tier</span>
                </div>
              </div>
            </a>
          </div>
        </section>

        <section className="section-dark" id="how">
          <p className="eyebrow reveal">How it works</p>
          <h2 className="section-title reveal">
            Three steps to
            <br />
            <span className="serif">your dream site</span>
          </h2>
          <div className="steps reveal">
            <div className="step">
              <div className="step-num">01</div>
              <span className="step-icon">🔍</span>
              <h3>Find Your Template</h3>
              <p>
                Browse template, script, and Web3 concepts. Verified releases
                and purchasing will appear here when ready; catalogue filters
                and checkout are not live yet.
              </p>
            </div>
            <div className="step">
              <div className="step-num">02</div>
              <span className="step-icon">⚡</span>
              <h3>Download & Deploy</h3>
              <p>
                Secure downloads and setup guides are planned for released products. Payment providers will be announced after integration and checkout testing.
              </p>
            </div>
            <div className="step">
              <div className="step-num">03</div>
              <span className="step-icon">🛠️</span>
              <h3>Need Customisation?</h3>
              <p>
                Custom implementation services are offered separately by Tinlance. Marketplace-linked service requests are planned, not live.
              </p>
            </div>
          </div>
        </section>

        <section>
          <p className="eyebrow reveal">Why Web-Temify</p>
          <h2 className="section-title reveal">
            Everything you need,
            <br />
            <span className="serif">nothing you don&apos;t</span>
          </h2>
          <div className="features-layout">
            <div className="feature-list reveal">
              <div className="feat-item">
                <div className="feat-icon">⚡</div>
                <div className="feat-text">
                  <h4>Lightning Fast Load Times</h4>
                  <p>
                    Every template is performance-optimised. Performance targets
                    will be published with tested releases.
                  </p>
                </div>
              </div>
              <div className="feat-item">
                <div className="feat-icon">📱</div>
                <div className="feat-text">
                  <h4>Mobile-First by Default</h4>
                  <p>
                    Perfect on phones, tablets, and desktops — no extra work
                    required from you.
                  </p>
                </div>
              </div>
              <div className="feat-item">
                <div className="feat-icon">🔍</div>
                <div className="feat-text">
                  <h4>SEO Built In</h4>
                  <p>
                    Meta tags, sitemaps, and structured data — all handled so
                    Google can find your site.
                  </p>
                </div>
              </div>
              <div className="feat-item">
                <div className="feat-icon">🔒</div>
                <div className="feat-text">
                  <h4>Secure delivery planned</h4>
                  <p>
                    Private, verified downloads and artifact scanning are
                    planned; delivery is not live.
                  </p>
                </div>
              </div>
              <div className="feat-item">
                <div className="feat-icon">💳</div>
                <div className="feat-text">
                  <h4>Payments planned</h4>
                  <p>
                    Payment-provider selection and onboarding are pending.
                    Checkout is disabled.
                  </p>
                </div>
              </div>
            </div>
            <div className="feature-visual reveal">
              <div className="fv-header">
                <span className="dot dot-r"></span>
                <span className="dot dot-y"></span>
                <span className="dot dot-g"></span>
                <span
                  style={{
                    color: "rgba(255, 255, 255, 0.4)",
                    fontSize: "0.7rem",
                    marginLeft: "0.5rem",
                    fontWeight: "700",
                  }}
                >
                  Template Gallery
                </span>
              </div>
              <div className="fv-body">
                <div className="mini-template">
                  <div
                    className="mt-hero"
                    style={{
                      background: "linear-gradient(135deg, #ff5733, #ffd60a)",
                    }}
                  >
                    <span style={{ fontSize: "1.4rem" }}>🏦</span>
                  </div>
                  <div className="mt-body">
                    <div
                      className="mt-line"
                      style={{ background: "#ff5733", width: "80%" }}
                    ></div>
                    <div
                      className="mt-line"
                      style={{ background: "#0f0d0a22", width: "60%" }}
                    ></div>
                  </div>
                  <div className="mt-label">NeoBank</div>
                </div>
                <div className="mini-template">
                  <div
                    className="mt-hero"
                    style={{
                      background: "linear-gradient(135deg, #4f8ef7, #c084fc)",
                    }}
                  >
                    <span style={{ fontSize: "1.4rem" }}>⛓️</span>
                  </div>
                  <div className="mt-body">
                    <div
                      className="mt-line"
                      style={{ background: "#4f8ef7", width: "70%" }}
                    ></div>
                    <div
                      className="mt-line"
                      style={{ background: "#0f0d0a22", width: "50%" }}
                    ></div>
                  </div>
                  <div className="mt-label">Web3 Kit</div>
                </div>
                <div className="mini-template">
                  <div
                    className="mt-hero"
                    style={{
                      background: "linear-gradient(135deg, #00c48c, #ffd60a)",
                    }}
                  >
                    <span style={{ fontSize: "1.4rem" }}>🚚</span>
                  </div>
                  <div className="mt-body">
                    <div
                      className="mt-line"
                      style={{ background: "#00c48c", width: "65%" }}
                    ></div>
                    <div
                      className="mt-line"
                      style={{ background: "#0f0d0a22", width: "45%" }}
                    ></div>
                  </div>
                  <div className="mt-label">Courier</div>
                </div>
                <div className="mini-template">
                  <div
                    className="mt-hero"
                    style={{
                      background: "linear-gradient(135deg, #ffd60a, #ff5733)",
                    }}
                  >
                    <span style={{ fontSize: "1.4rem" }}>💱</span>
                  </div>
                  <div className="mt-body">
                    <div
                      className="mt-line"
                      style={{ background: "#ffd60a", width: "75%" }}
                    ></div>
                    <div
                      className="mt-line"
                      style={{ background: "#0f0d0a22", width: "55%" }}
                    ></div>
                  </div>
                  <div className="mt-label">P2P Script</div>
                </div>
              </div>
            </div>
          </div>
        </section>

        <section className="section-alt" id="services">
          <div className="section-head reveal">
            <div>
              <p className="eyebrow">Services by Tinlance</p>
              <h2 className="section-title">
                Need it built
                <br />
                <span className="serif">from scratch?</span>
              </h2>
              <p
                style={{
                  fontSize: "0.9rem",
                  color: "var(--muted)",
                  marginTop: "0.75rem",
                  fontWeight: "500",
                  maxWidth: "400px",
                }}
              >
                Our engineering team builds custom products for founders and
                businesses across Africa.
              </p>
            </div>
            <a
              href="https://tinlance.com"
              target="_blank"
              rel="noreferrer"
              className="btn btn-fill"
            >
              Request a Service ↗
            </a>
          </div>
          <div className="services-grid reveal">
            <div className="svc-card">
              <span className="svc-icon">🌐</span>
              <div className="svc-name">Custom Website Build</div>
              <div className="svc-desc">
                Professional websites and landing pages designed to convert and
                built to perform.
              </div>
              <div className="svc-price">Scope-based quote</div>
            </div>
            <div className="svc-card">
              <span className="svc-icon">⛓️</span>
              <div className="svc-name">Web3 / DApp Development</div>
              <div className="svc-desc">
                Smart contracts, DeFi interfaces, and wallet integrations.
                Ethereum, Solana, Polygon.
              </div>
              <div className="svc-price">Scope-based quote</div>
            </div>
            <div className="svc-card">
              <span className="svc-icon">🚀</span>
              <div className="svc-name">SaaS MVP Build</div>
              <div className="svc-desc">
                Full-stack SaaS with auth, billing, and dashboards —
                production-ready in weeks.
              </div>
              <div className="svc-price">Scope-based quote</div>
            </div>
            <div className="svc-card">
              <span className="svc-icon">🏦</span>
              <div className="svc-name">Fintech Solutions</div>
              <div className="svc-desc">
                Payment systems, loan platforms, and Paystack integrations for
                African markets.
              </div>
              <div className="svc-price">Scope-based quote</div>
            </div>
            <div className="svc-card">
              <span className="svc-icon">🎨</span>
              <div className="svc-name">Template Customisation</div>
              <div className="svc-desc">
                Bought a template? We customise it to your brand and deploy it
                for you.
              </div>
              <div className="svc-price">Scope-based quote</div>
            </div>
            <div className="svc-card">
              <span className="svc-icon">🔗</span>
              <div className="svc-name">API & Integrations</div>
              <div className="svc-desc">
                Third-party APIs, webhook systems, and automation pipelines for
                any stack.
              </div>
              <div className="svc-price">Scope-based quote</div>
            </div>
          </div>
        </section>

        <section>
          <div className="vendor-box reveal">
            <div>
              <p className="eyebrow">Become a Vendor</p>
              <h2
                className="section-title"
                style={{ fontSize: "clamp(1.6rem, 3vw, 2.4rem)" }}
              >
                Sell your templates
                <br />
                <span className="serif">& scripts here</span>
              </h2>
              <p
                style={{
                  fontSize: "0.9rem",
                  color: "var(--ink)",
                  marginTop: "0.75rem",
                  fontWeight: "500",
                  maxWidth: "400px",
                  opacity: "0.7",
                }}
              >
                Seller onboarding is planned. Seller earnings, payments,
                delivery, and support workflows are not live.
              </p>
              <div className="vendor-steps-list">
                <div className="vstep">
                  <span className="vstep-num">1</span> Create your vendor
                  account and complete your profile
                </div>
                <div className="vstep">
                  <span className="vstep-num">2</span> Upload your product with
                  screenshots and demo link
                </div>
                <div className="vstep">
                  <span className="vstep-num">3</span> Seller review timelines
                  will be published before onboarding opens
                </div>
                <div className="vstep">
                  <span className="vstep-num">4</span> Payout providers and
                  supported jurisdictions are not confirmed; payouts are
                  disabled
                </div>
              </div>
            </div>
            <div
              style={{
                textAlign: "center",
                display: "flex",
                flexDirection: "column",
                gap: "1.25rem",
                alignItems: "center",
              }}
            >
              <div>
                <div
                  style={{
                    fontSize: "3.5rem",
                    fontWeight: "900",
                    letterSpacing: "-0.05em",
                  }}
                >
                  Terms TBD
                </div>
                <div
                  style={{
                    fontSize: "0.72rem",
                    fontWeight: "800",
                    textTransform: "uppercase",
                    letterSpacing: "0.1em",
                    opacity: "0.6",
                  }}
                >
                  Seller terms pending
                </div>
              </div>
              <span className="btn btn-dark btn-big" aria-disabled="true">
                Seller onboarding not live
              </span>
              <div
                style={{
                  fontSize: "0.75rem",
                  opacity: "0.55",
                  fontWeight: "700",
                }}
              >
                Free to join · No monthly fees
              </div>
            </div>
          </div>
        </section>

        <section className="section-alt">
          <div className="section-head reveal">
            <div>
              <p className="eyebrow">Rewards & Community</p>
              <h2 className="section-title">
                Rewards programme,
                <br />
                <span className="serif">planned for later</span>
              </h2>
            </div>
          </div>
          <div className="gamify-grid reveal">
            <div className="gamify-card">
              <span className="gamify-icon">🏆</span>
              <div className="gamify-name">Rewards programme (planned)</div>
              <div className="gamify-desc">
                Rewards and referral features are planned and not available yet.
              </div>
            </div>
            <div className="gamify-card">
              <span className="gamify-icon">🎖️</span>
              <div className="gamify-name">Unlock Badges</div>
              <div className="gamify-desc">
                Early Adopter, Web3 Pioneer, Review Champion — visible on your
                public profile
              </div>
            </div>
            <div className="gamify-card">
              <span className="gamify-icon">📊</span>
              <div className="gamify-name">Leaderboard</div>
              <div className="gamify-desc">
                Top buyers, top vendors, and top reviewers ranked monthly with
                cash rewards
              </div>
            </div>
            <div className="gamify-card">
              <span className="gamify-icon">🤝</span>
              <div className="gamify-name">Referral programme (planned)</div>
              <div className="gamify-desc">
                Referral programme is planned; commission terms are not live
              </div>
            </div>
          </div>
        </section>

        <section>
          <p className="eyebrow reveal">Product direction</p>
          <h2 className="section-title reveal">
            Designed for
            <br />
            <span className="serif">real builders</span>
          </h2>
          <div className="testi-grid reveal">
            <div className="testi-card tc-1">
              <div className="testi-stars">PREVIEW</div>
              <p className="testi-quote">
                “Illustrative concept only. Verified customer reviews will be
                published after real transactions and consent.”
              </p>
              <div className="testi-author">
                <div className="testi-avatar" style={{ background: "#ffd6c0" }}>
                  👨🏾
                </div>
                <div>
                  <div className="testi-name">Template marketplace</div>
                  <div className="testi-role">
                    Planned capability · Not live
                  </div>
                </div>
              </div>
            </div>
            <div className="testi-card tc-2">
              <div className="testi-stars">PREVIEW</div>
              <p className="testi-quote">
                “Automation listings will disclose supported systems, required
                permissions, tests, and rollback guidance before publication.”
              </p>
              <div className="testi-author">
                <div className="testi-avatar" style={{ background: "#c8f0e0" }}>
                  👩🏾
                </div>
                <div>
                  <div className="testi-name">Automation marketplace</div>
                  <div className="testi-role">
                    Planned capability · Not live
                  </div>
                </div>
              </div>
            </div>
            <div className="testi-card tc-3">
              <div className="testi-stars">PREVIEW</div>
              <p className="testi-quote">
                “Supplier and implementation listings will use evidence-backed
                profiles and explicit scope. No escrow or outcome guarantees are
                implied.”
              </p>
              <div className="testi-author">
                <div className="testi-avatar" style={{ background: "#fef9c3" }}>
                  👨🏾
                </div>
                <div>
                  <div className="testi-name">Specialist directory</div>
                  <div className="testi-role">
                    Planned capability · Not live
                  </div>
                </div>
              </div>
            </div>
          </div>
        </section>

        <section className="section-alt" id="pricing">
          <p className="eyebrow reveal" style={{ textAlign: "center" }}>
            Pricing
          </p>
          <h2
            className="section-title reveal"
            style={{ textAlign: "center", margin: "0 auto" }}
          >
            Simple pricing,
            <br />
            <span className="serif">no surprises</span>
          </h2>
          <p
            style={{
              textAlign: "center",
              fontSize: "0.9rem",
              color: "var(--muted)",
              margin: "0.75rem auto 0",
              fontWeight: "500",
              maxWidth: "420px",
            }}
            className="reveal"
          >
            Pricing below is illustrative only. Plans, subscriptions, and
            checkout are not available yet.
          </p>
          <div className="pricing-grid reveal">
            <div className="price-card">
              <div className="price-top">
                <div className="price-label">Free</div>
                <div className="price-amount">Preview</div>
                <div className="price-period">Not available yet</div>
              </div>
              <div className="price-features">
                <div className="pf-item">
                  <div className="pf-check">✓</div>
                  Free templates
                </div>
                <div className="pf-item">
                  <div className="pf-check">✓</div>
                  Browse directory
                </div>
                <div className="pf-item">
                  <div className="pf-check">✓</div>
                  Community forum
                </div>
                <div className="pf-item pf-off">
                  <div className="pf-check">✗</div>
                  Premium templates
                </div>
                <div className="pf-item pf-off">
                  <div className="pf-check">✗</div>
                  Scripts & kits
                </div>
              </div>
              <div className="price-footer">
                <span
                  className="btn btn-ghost"
                  style={{ width: "100%", textAlign: "center" }}
                  aria-disabled="true"
                  title="Plans are not live yet"
                >
                  Not available yet
                </span>
              </div>
            </div>
            <div className="price-card featured">
              <div className="price-top">
                <div className="price-label">Pro ⭐ Most Popular</div>
                <div className="price-amount">Preview</div>
                <div className="price-period">Not available yet</div>
              </div>
              <div className="price-features">
                <div className="pf-item">
                  <div className="pf-check">✓</div>
                  All planned templates
                </div>
                <div className="pf-item">
                  <div className="pf-check">✓</div>
                  All scripts & kits
                </div>
                <div className="pf-item">
                  <div className="pf-check">✓</div>
                  API access
                </div>
                <div className="pf-item">
                  <div className="pf-check">✓</div>
                  Priority support
                </div>
                <div className="pf-item">
                  <div className="pf-check">✓</div>
                  Dark mode + collections
                </div>
              </div>
              <div className="price-footer">
                <span
                  className="btn btn-yellow"
                  style={{
                    width: "100%",
                    textAlign: "center",
                    borderColor: "transparent",
                  }}
                  aria-disabled="true"
                  title="Plans are not live yet"
                >
                  Not available yet
                </span>
              </div>
            </div>
            <div className="price-card">
              <div className="price-top">
                <div className="price-label">Business</div>
                <div className="price-amount">Preview</div>
                <div className="price-period">Not available yet</div>
              </div>
              <div className="price-features">
                <div className="pf-item">
                  <div className="pf-check">✓</div>
                  Everything in Pro
                </div>
                <div className="pf-item">
                  <div className="pf-check">✓</div>
                  White-label rights
                </div>
                <div className="pf-item">
                  <div className="pf-check">✓</div>
                  Volume licensing
                </div>
                <div className="pf-item">
                  <div className="pf-check">✓</div>
                  Early access
                </div>
                <div className="pf-item pf-off">
                  <div className="pf-check">✗</div>
                  Team seats
                </div>
              </div>
              <div className="price-footer">
                <span
                  className="btn btn-fill"
                  style={{ width: "100%", textAlign: "center" }}
                  aria-disabled="true"
                  title="Plans are not live yet"
                >
                  Not available yet
                </span>
              </div>
            </div>
            <div className="price-card">
              <div className="price-top">
                <div className="price-label">Agency</div>
                <div className="price-amount">Preview</div>
                <div className="price-period">Not available yet</div>
              </div>
              <div className="price-features">
                <div className="pf-item">
                  <div className="pf-check">✓</div>
                  Everything in Business
                </div>
                <div className="pf-item">
                  <div className="pf-check">✓</div>5 team seats
                </div>
                <div className="pf-item">
                  <div className="pf-check">✓</div>
                  Unlimited client sites
                </div>
                <div className="pf-item">
                  <div className="pf-check">✓</div>
                  Dedicated support
                </div>
                <div className="pf-item">
                  <div className="pf-check">✓</div>
                  Custom invoicing
                </div>
              </div>
              <div className="price-footer">
                <span
                  className="btn btn-ghost"
                  style={{ width: "100%", textAlign: "center" }}
                  aria-disabled="true"
                  title="Plans are not live yet"
                >
                  Not available yet
                </span>
              </div>
            </div>
          </div>
        </section>

        <section>
          <div className="nl-box reveal">
            <div>
              <p className="eyebrow">Stay in the Loop</p>
              <h2
                className="section-title"
                style={{ fontSize: "clamp(1.4rem, 2.5vw, 2rem)" }}
              >
                New templates every week.
                <br />
                <span className="serif">Dev tips. Tool discoveries.</span>
              </h2>
              <p
                style={{
                  fontSize: "0.875rem",
                  color: "var(--muted)",
                  marginTop: "0.6rem",
                  fontWeight: "500",
                }}
              >
                Join developers. No spam — only the good stuff.
              </p>
            </div>
            <div>
              <div className="nl-form">
                <input
                  type="email"
                  className="nl-input"
                  placeholder="your@email.com"
                />
                <button className="btn btn-fill" type="button" disabled>
                  Signup coming soon
                </button>
              </div>
              <p
                style={{
                  fontSize: "0.72rem",
                  color: "var(--muted)",
                  marginTop: "0.6rem",
                }}
              >
                By subscribing you agree to our Privacy Policy (coming soon).
              </p>
            </div>
          </div>
        </section>

        <section className="cta-section">
          <div className="cta-bg-text">LAUNCH</div>
          <h2>
            Ready to build
            <br />
            your <span className="serif">dream product?</span>
          </h2>
          <p>
            Marketplace updates and tool discoveries. Newsletter signup is not
            live yet.
          </p>
          <div className="cta-buttons">
            <a href="#templates" className="btn btn-white btn-big">
              Browse Templates →
            </a>
            <a href="#services" className="btn btn-outline-white btn-big">
              Talk to us
            </a>
          </div>
        </section>
      </main>
      <footer>
        <div className="footer-brand">
          <Link href="/" className="logo">
            Web-Temify <span className="logo-dot"></span>
          </Link>
          <p>
            Premium templates, scripts, Web3 kits, and dev tools for builders
            across Africa and beyond. No code, no stress.
          </p>
          <div className="footer-badges-row">
            <span className="f-badge">🇳🇬 Nigeria</span>
            <span className="f-badge">RC: 7999659</span>
          </div>
          <div
            className="sister"
            style={{
              marginTop: "1rem",
              fontSize: "0.7rem",
              fontWeight: "700",
              color: "var(--muted)",
              borderTop: "1.5px solid var(--ink)",
              paddingTop: "0.8rem",
            }}
          >
            A sister company of
            <a
              href="https://tinlance.com"
              target="_blank"
              rel="noreferrer"
              style={{ color: "var(--coral)", fontWeight: "800" }}
            >
              Tinlance Limited ↗
            </a>
            <br />
            Need a custom-built product? That&apos;s their lane.
          </div>
        </div>
        <div className="footer-col">
          <h5>Marketplace</h5>
          <ul>
            <li>
              <Link href="/catalog">All Templates</Link>
            </li>
            <li>
              <Link href="/catalog">Scripts</Link>
            </li>
            <li>
              <Link href="/catalog">Launch Kits</Link>
            </li>
            <li>
              <Link href="/catalog">Web3 Hub</Link>
            </li>
            <li>
              <Link href="/catalog">Free Templates</Link>
            </li>
            <li>
              <Link href="/catalog">New Arrivals</Link>
            </li>
          </ul>
        </div>
        <div className="footer-col">
          <h5>Directory</h5>
          <ul>
            <li>
              <Link href="/catalog">All Tools</Link>
            </li>
            <li>
              <Link href="/catalog">AI Tools</Link>
            </li>
            <li>
              <Link href="/catalog">Web3 Tools</Link>
            </li>
            <li>
              <Link href="/catalog">Hosting</Link>
            </li>
            <li>
              <Link href="/catalog">Design Tools</Link>
            </li>
            <li>
              <span
                aria-disabled="true"
                title="This destination is not live yet"
              >
                Submit a Tool (coming soon)
              </span>
            </li>
          </ul>
        </div>
        <div className="footer-col">
          <h5>Platform</h5>
          <ul>
            <li>
              <a href="#pricing">Pricing</a>
            </li>
            <li>
              <span
                aria-disabled="true"
                title="This destination is not live yet"
              >
                Become a Vendor (coming soon)
              </span>
            </li>
            <li>
              <a href="#services">Services</a>
            </li>
            <li>
              <span
                aria-disabled="true"
                title="This destination is not live yet"
              >
                Affiliates (coming soon)
              </span>
            </li>
            <li>
              <span
                aria-disabled="true"
                title="This destination is not live yet"
              >
                API Docs (coming soon)
              </span>
            </li>
            <li>
              <span
                aria-disabled="true"
                title="This destination is not live yet"
              >
                Blog (coming soon)
              </span>
            </li>
          </ul>
        </div>
        <div className="footer-col">
          <h5>Company</h5>
          <ul>
            <li>
              <span
                aria-disabled="true"
                title="This destination is not live yet"
              >
                Our Story (coming soon)
              </span>
            </li>
            <li>
              <span
                aria-disabled="true"
                title="This destination is not live yet"
              >
                Roadmap (coming soon)
              </span>
            </li>
            <li>
              <span
                aria-disabled="true"
                title="This destination is not live yet"
              >
                Changelog (coming soon)
              </span>
            </li>
            <li>
              <span
                aria-disabled="true"
                title="This destination is not live yet"
              >
                Press Kit (coming soon)
              </span>
            </li>
            <li>
              <span
                aria-disabled="true"
                title="This destination is not live yet"
              >
                Privacy (coming soon)
              </span>
            </li>
            <li>
              <span
                aria-disabled="true"
                title="This destination is not live yet"
              >
                Terms (coming soon)
              </span>
            </li>
          </ul>
        </div>
      </footer>
      <div className="footer-bottom">
        <span>© 2026 Web-Temify LTD. All rights reserved. RC: 7999659</span>
        <div className="footer-socials">
          <span
            className="social-btn"
            aria-disabled="true"
            title="Social profile not configured"
          >
            𝕏
          </span>
          <span
            className="social-btn"
            aria-disabled="true"
            title="Social profile not configured"
          >
            ⌥
          </span>
          <span
            className="social-btn"
            aria-disabled="true"
            title="Social profile not configured"
          >
            📱
          </span>
          <span
            className="social-btn"
            aria-disabled="true"
            title="Social profile not configured"
          >
            in
          </span>
        </div>
      </div>
    </div>
  );
}
