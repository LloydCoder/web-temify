import type { Metadata } from "next";
import Link from "next/link";
import "./v3-home.css";
import V3Navigation from "@/components/v3-navigation";
import V3DirectoryControls from "@/components/v3-directory-controls";
import V3PromptChips from "@/components/v3-prompt-chips";
import V3HomepageInteractions from "@/components/v3-homepage-interactions";

export const metadata: Metadata = {
  alternates: { canonical: "/" },
};

export default function HomePage() {
  return (
    <div className="v3-app">
      <a className="skip-link" href="#main-content">
        Skip to main content
      </a>
      <V3Navigation />
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
              Your next website,
              <br />
              <span className="serif">starts</span>
              <br />
              here.
            </h1>
            <p className="hero-desc">
              Explore the Web-Temify marketplace concept: templates, launch
              kits, scripts, and tools for builders. The catalogue, seller
              features, and checkout are not live yet; no products are available
              for purchase.
            </p>
            <div className="hero-cta">
              <a href="#templates" className="btn btn-fill btn-big">
                Explore previews
              </a>
              <a href="#how" className="btn btn-ghost btn-big">
                See how it works
              </a>
            </div>
            <div className="hero-trust">
              <div className="trust-text">
                <strong>Marketplace concept</strong>
                <br />
                Preview only · no accounts or checkout yet
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
            <Link
              href={`/catalog?q=${encodeURIComponent("Fintech & Banking")}`}
              className="cat-card cc-1"
              aria-label="Fintech & Banking — browse the catalogue"
            >
              <span className="cat-count">Preview</span>
              <span className="cat-emoji">🏦</span>
              <h3>Fintech & Banking</h3>
              <p>
                Banking UIs, loan platforms, and payment-system concepts for
                global and regional markets.
              </p>
            </Link>
            <Link
              href={`/catalog?q=${encodeURIComponent("Web3 & Blockchain")}`}
              className="cat-card cc-2"
              aria-label="Web3 & Blockchain — browse the catalogue"
            >
              <span className="cat-count">Preview</span>
              <span className="cat-emoji">⛓️</span>
              <h3>Web3 & Blockchain</h3>
              <p>
                NFT marketplaces, DeFi dashboards, DAO governance, and wallet UI
                kits.
              </p>
            </Link>
            <Link
              href={`/catalog?q=${encodeURIComponent("Logistics & Courier")}`}
              className="cat-card cc-3"
              aria-label="Logistics & Courier — browse the catalogue"
            >
              <span className="cat-count">Preview</span>
              <span className="cat-emoji">🚚</span>
              <h3>Logistics & Courier</h3>
              <p>
                Delivery company sites with rate calculators, tracking UI, and
                fleet management.
              </p>
            </Link>
            <Link
              href={`/catalog?q=${encodeURIComponent("SaaS & Startups")}`}
              className="cat-card cc-4"
              aria-label="SaaS & Startups — browse the catalogue"
            >
              <span className="cat-count">Preview</span>
              <span className="cat-emoji">🚀</span>
              <h3>SaaS & Startups</h3>
              <p>
                Modern landing pages, app showcases, and product-led growth
                templates.
              </p>
            </Link>
            <Link
              href={`/catalog?q=${encodeURIComponent("Agency & Portfolio")}`}
              className="cat-card cc-5"
              aria-label="Agency & Portfolio — browse the catalogue"
            >
              <span className="cat-count">Preview</span>
              <span className="cat-emoji">🎨</span>
              <h3>Agency & Portfolio</h3>
              <p>
                Bold, conversion-focused designs for creative agencies and
                freelancers.
              </p>
            </Link>
            <Link
              href={`/catalog?q=${encodeURIComponent("E-commerce")}`}
              className="cat-card cc-6"
              aria-label="E-commerce — browse the catalogue"
            >
              <span className="cat-count">Preview</span>
              <span className="cat-emoji">🛒</span>
              <h3>E-commerce</h3>
              <p>
                Ready-to-sell storefronts for digital products, subscriptions,
                and physical goods.
              </p>
            </Link>
            <Link
              href={`/catalog?q=${encodeURIComponent("Real Estate")}`}
              className="cat-card cc-7"
              aria-label="Real Estate — browse the catalogue"
            >
              <span className="cat-count">Preview</span>
              <span className="cat-emoji">🏘️</span>
              <h3>Real Estate</h3>
              <p>
                Property listing, agent profiles, and developer portfolio
                templates.
              </p>
            </Link>
            <Link
              href={`/catalog?q=${encodeURIComponent("Scripts & Tools")}`}
              className="cat-card cc-8"
              aria-label="Scripts & Tools — browse the catalogue"
            >
              <span className="cat-count">Preview</span>
              <span className="cat-emoji">⚡</span>
              <h3>Scripts & Tools</h3>
              <p>
                Planned script categories include P2P trading, loan management,
                banking, POS, and more.
              </p>
            </Link>
          </div>
        </section>

        <section className="section-alt" id="featured">
          <div className="section-head reveal">
            <div>
              <p className="eyebrow">Featured Products</p>
              <h2 className="section-title">
                Template & script previews
                <br />
                <span className="serif">for your next build</span>
              </h2>
            </div>
            <Link href="/catalog" className="btn btn-ghost">
              Browse catalogue →
            </Link>
          </div>
          <div className="templates-grid reveal">
            <div className="tpl-card">
              <div className="tpl-preview" style={{ background: "#fff5f0" }}>
                <span className="tpl-badge badge-hot">Preview</span>🏦
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
                <span className="tpl-badge badge-new">Preview</span>🚚
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
                <span className="tpl-badge badge-hot">Preview</span>💱
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
                <span className="tpl-badge badge-new">Preview</span>🏘️
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
                <span className="tpl-badge badge-top">Preview</span>💰
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
                Planned launch kits will bundle a project&apos;s core pieces.
                These cards are previews, not released products.
              </p>
            </div>
          </div>
          <div className="kits-grid reveal">
            <div className="kit-card dark">
              <div className="kit-watermark">🚀</div>
              <div className="kit-tag">SaaS concept preview</div>
              <div className="kit-name">SaaS Starter Kit</div>
              <div className="kit-desc">
                Concept preview: a SaaS starter bundle may include auth,
                billing, a dashboard, onboarding, and a landing page. Not
                available for purchase yet.
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
                    Preview · Not available
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
                Planned bundle: wallet connection and smart-contract UI, token
                dashboard, and NFT components. Not available yet.
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
                  <span className="kit-price">Preview · Not available</span>
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
                Region-aware fintech UI, loan calculator, and KYC flow. Validate
                payment providers and jurisdictions for each market.
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
                  <span className="kit-price">Preview · Not available</span>
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
                Planned agency bundle: portfolio, services pages, case studies,
                contact forms, and lead capture. Not available yet.
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
                  <span className="kit-price">Preview · Not available</span>
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
                aria-label="Website description (preview only)"
                aria-describedby="ai-builder-status"
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
            </div>
            <p
              id="ai-builder-status"
              className="ai-builder-status"
              role="status"
            >
              AI generation is not live yet.
            </p>
            <V3PromptChips />
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
            <Link
              href={`/catalog?q=${encodeURIComponent("Wallet Auth UI")}`}
              className="web3-card"
              aria-label="Wallet Auth UI — browse the catalogue"
            >
              <span className="web3-icon">👛</span>
              <div className="web3-name">Wallet Auth UI</div>
              <div className="web3-desc">
                MetaMask, WalletConnect, Coinbase — ready-made connection flows
                for any project
              </div>
            </Link>
            <Link
              href={`/catalog?q=${encodeURIComponent("NFT Galleries")}`}
              className="web3-card"
              aria-label="NFT Galleries — browse the catalogue"
            >
              <span className="web3-icon">🖼️</span>
              <div className="web3-name">NFT Galleries</div>
              <div className="web3-desc">
                Collection displays, mint pages, and auction interfaces built
                and tested
              </div>
            </Link>
            <Link
              href={`/catalog?q=${encodeURIComponent("DeFi Dashboards")}`}
              className="web3-card"
              aria-label="DeFi Dashboards — browse the catalogue"
            >
              <span className="web3-icon">📊</span>
              <div className="web3-name">DeFi Dashboards</div>
              <div className="web3-desc">
                Staking, liquidity pools, and yield farming — complete UI kits
                ready to download
              </div>
            </Link>
            <Link
              href={`/catalog?q=${encodeURIComponent("DAO Governance")}`}
              className="web3-card"
              aria-label="DAO Governance — browse the catalogue"
            >
              <span className="web3-icon">🏛️</span>
              <div className="web3-name">DAO Governance</div>
              <div className="web3-desc">
                Proposal voting, treasury management, and member portals for
                your community
              </div>
            </Link>
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
          <V3DirectoryControls />
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
                  AI assistant for coding, writing, and complex analysis tasks
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
                  Deploy web projects with previews and frontend hosting.
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
                  Payment infrastructure for businesses, including cards, bank
                  transfers, USSD, and mobile money.
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
            <a
              className="dir-card"
              href="https://webflow.com/"
              target="_blank"
              rel="noreferrer"
              data-directory="no-code visual website builder"
            >
              <div className="dir-logo">◈</div>
              <div className="dir-info">
                <div className="dir-name">Webflow</div>
                <div className="dir-desc">
                  Visual website design and publishing platform for building
                  responsive websites.
                </div>
                <div className="dir-pills">
                  <span className="dir-pill">No-code</span>
                  <span className="dir-pill">Visual design</span>
                  <span className="dir-pill">Websites</span>
                </div>
              </div>
            </a>
            <a
              className="dir-card"
              href="https://bubble.io/"
              target="_blank"
              rel="noreferrer"
              data-directory="no-code visual app builder"
            >
              <div className="dir-logo">🫧</div>
              <div className="dir-info">
                <div className="dir-name">Bubble</div>
                <div className="dir-desc">
                  Visual no-code platform for building interactive web
                  applications.
                </div>
                <div className="dir-pills">
                  <span className="dir-pill">No-code</span>
                  <span className="dir-pill">App builder</span>
                  <span className="dir-pill">Visual</span>
                </div>
              </div>
            </a>
            <a
              className="dir-card"
              href="https://contra.com/"
              target="_blank"
              rel="noreferrer"
              data-directory="freelancer resources client portfolio projects"
            >
              <div className="dir-logo">✳</div>
              <div className="dir-info">
                <div className="dir-name">Contra</div>
                <div className="dir-desc">
                  Independent-work platform for freelancer portfolios and client
                  project discovery.
                </div>
                <div className="dir-pills">
                  <span className="dir-pill">Freelancers</span>
                  <span className="dir-pill">Portfolio</span>
                  <span className="dir-pill">Clients</span>
                </div>
              </div>
            </a>
            <a
              className="dir-card"
              href="https://www.waveapps.com/"
              target="_blank"
              rel="noreferrer"
              data-directory="freelancer resources invoice invoicing billing"
            >
              <div className="dir-logo">🌊</div>
              <div className="dir-info">
                <div className="dir-name">Wave</div>
                <div className="dir-desc">
                  Invoicing and small-business accounting tools that can help
                  independent professionals manage client billing.
                </div>
                <div className="dir-pills">
                  <span className="dir-pill">Invoicing</span>
                  <span className="dir-pill">Billing</span>
                  <span className="dir-pill">Freelancers</span>
                </div>
              </div>
            </a>
          </div>
          <p className="dir-empty-state" role="status" hidden>
            No matching tools are included in this preview yet.
          </p>
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
                Secure downloads and setup guides are planned for released
                products. Payment providers will be announced after integration
                and checkout testing.
              </p>
            </div>
            <div className="step">
              <div className="step-num">03</div>
              <span className="step-icon">🛠️</span>
              <h3>Need Customisation?</h3>
              <p>
                Custom implementation services are offered separately by
                Tinlance. Marketplace-linked service requests are planned, not
                live.
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
                    Released templates will be tested against published
                    performance targets before they are marked verified.
                  </p>
                </div>
              </div>
              <div className="feat-item">
                <div className="feat-icon">📱</div>
                <div className="feat-text">
                  <h4>Mobile-First by Default</h4>
                  <p>
                    Responsive behavior will be tested across phones, tablets,
                    and desktops before a release is marked verified.
                  </p>
                </div>
              </div>
              <div className="feat-item">
                <div className="feat-icon">🔍</div>
                <div className="feat-text">
                  <h4>SEO Built In</h4>
                  <p>
                    SEO requirements, including metadata and structured data,
                    will be documented and tested for verified releases.
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
              <div className="fv-header" style={{ backgroundColor: "#0f0d0a" }}>
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
                Tinlance delivers custom engineering worldwide, with
                region-specific implementation where needed.
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
                Full-stack SaaS with authentication, billing, and dashboards,
                scoped to your launch requirements.
              </div>
              <div className="svc-price">Scope-based quote</div>
            </div>
            <div className="svc-card">
              <span className="svc-icon">🏦</span>
              <div className="svc-name">Fintech Solutions</div>
              <div className="svc-desc">
                Payment systems, loan platforms, and payment integrations for
                global and regional markets, subject to provider and
                jurisdiction support.
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
                <div className="price-label">Pro · Planned</div>
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
                New releases.
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
                  aria-label="Email address for future Web-Temify updates"
                  aria-describedby="newsletter-status"
                  placeholder="Newsletter signup coming soon"
                  disabled
                />
                <button className="btn btn-fill" type="button" disabled>
                  Signup coming soon
                </button>
              </div>
              <p
                id="newsletter-status"
                role="status"
                style={{
                  fontSize: "0.72rem",
                  color: "var(--muted)",
                  marginTop: "0.6rem",
                }}
              >
                {"Newsletter signup and the privacy policy are not live yet. " +
                  "No email is collected."}
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
            <a href="#services" className="btn btn-outline-ink btn-big">
              Talk to us
            </a>
          </div>
        </section>

        <section
          className="ecosystem-section"
          id="ecosystem"
          aria-labelledby="ecosystem-title"
        >
          <div className="ecosystem-inner">
            <div className="ecosystem-heading">
              <p className="section-eyebrow">THE WEB-TEMIFY ECOSYSTEM</p>
              <h2 id="ecosystem-title">
                One platform. <span className="serif">More ways to build.</span>
              </h2>
              <p>
                Explore the nine connected areas of Web-Temify. Each destination
                is explicit about what is available today and what remains in
                development.
              </p>
            </div>
            <div className="ecosystem-grid">
              <article className="ecosystem-card ecosystem-card-live">
                <span className="ecosystem-number">01</span>
                <p className="ecosystem-status">
                  Existing route · verified catalogue rules
                </p>
                <h3>Template &amp; Script Marketplace</h3>
                <p>
                  Browse the catalogue. Only products meeting the existing
                  publication and release checks should be presented as
                  purchasable.
                </p>
                <Link className="btn btn-fill" href="/catalog">
                  Browse catalogue →
                </Link>
              </article>
              <article className="ecosystem-card">
                <span className="ecosystem-number">02</span>
                <p className="ecosystem-status">Planned · not operational</p>
                <h3>Web Hosting &amp; Deployment</h3>
                <p>
                  Hosting plans, deployment automation, domains, SSL and site
                  operations are planned; provisioning and billing are not
                  available here.
                </p>
                <Link className="ecosystem-link" href="/hosting">
                  Explore hosting roadmap →
                </Link>
              </article>
              <article className="ecosystem-card">
                <span className="ecosystem-number">03</span>
                <p className="ecosystem-status">
                  Planned · generation disabled
                </p>
                <h3>AI Site Builder</h3>
                <p>
                  Prompt-to-site creation is a roadmap capability. This page
                  does not generate or deploy a website.
                </p>
                <Link className="ecosystem-link" href="/ai-site-builder">
                  Explore AI Site Builder →
                </Link>
              </article>
              <article className="ecosystem-card">
                <span className="ecosystem-number">04</span>
                <p className="ecosystem-status">
                  Preview · submissions not live
                </p>
                <h3>Tech Directory Hub</h3>
                <p>
                  Explore selected external tools in the homepage preview.
                  Listing submissions, paid placements and a managed directory
                  are not enabled.
                </p>
                <Link className="ecosystem-link" href="/directory">
                  Explore directory status →
                </Link>
              </article>
              <article className="ecosystem-card">
                <span className="ecosystem-number">05</span>
                <p className="ecosystem-status">
                  Planned · transactions disabled
                </p>
                <h3>Verified Automation Marketplace</h3>
                <p>
                  Automation discovery, verification, installation and managed
                  updates are planned, not available as a live marketplace.
                </p>
                <Link className="ecosystem-link" href="/automations">
                  Explore automation roadmap →
                </Link>
              </article>
              <article className="ecosystem-card">
                <span className="ecosystem-number">06</span>
                <p className="ecosystem-status">
                  Planned · supplier onboarding closed
                </p>
                <h3>Specialist Supplier Directory</h3>
                <p>
                  A verified supplier directory is planned. Supplier profiles,
                  verification and marketplace enquiries are not yet
                  operational.
                </p>
                <Link className="ecosystem-link" href="/specialists">
                  Explore supplier roadmap →
                </Link>
              </article>
              <article className="ecosystem-card">
                <span className="ecosystem-number">07</span>
                <p className="ecosystem-status">
                  Planned · milestone payments disabled
                </p>
                <h3>Outcome-Based AI Implementation</h3>
                <p>
                  Scoped delivery, acceptance criteria and milestone-based
                  engagement are planned. No marketplace contract or payment can
                  be initiated here.
                </p>
                <Link className="ecosystem-link" href="/implementation">
                  Explore implementation roadmap →
                </Link>
              </article>
              <article className="ecosystem-card">
                <span className="ecosystem-number">08</span>
                <p className="ecosystem-status">
                  Shared foundation · not a storefront
                </p>
                <h3>Shared Enterprise Platform</h3>
                <p>
                  Identity, policy, approvals, auditability, secure delivery and
                  operational controls underpin the ecosystem. Their presence
                  does not mean every product feature is enabled.
                </p>
                <Link className="ecosystem-link" href="/platform">
                  Understand the platform layer →
                </Link>
              </article>
              <article className="ecosystem-card">
                <span className="ecosystem-number">09</span>
                <p className="ecosystem-status">
                  Planned · monetization not enabled
                </p>
                <h3>Tech Hub &amp; Advertising Engine</h3>
                <p>
                  Editorial content, SEO resources, affiliate disclosures,
                  sponsored placements and newsletter sponsorships require
                  dedicated publishing and commercial workflows.
                </p>
                <Link className="ecosystem-link" href="/tech-hub">
                  Explore Tech Hub roadmap →
                </Link>
              </article>
            </div>
            <p className="ecosystem-disclaimer">
              Availability is feature-specific. Planned cards are roadmap
              disclosures, not promises of launch dates. Payment processing,
              seller payouts and live money movement remain disabled until the
              required technical, legal, security and operational gates are
              verified.
            </p>
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
            for builders worldwide. No code, no stress.
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
              style={{ color: "#a83218", fontWeight: "800" }}
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
      <V3HomepageInteractions />
    </div>
  );
}
