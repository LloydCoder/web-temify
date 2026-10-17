"use client";

import Link from "next/link";
import { useState } from "react";

export default function V3Navigation() {
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);

  return (
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
        <li>
          <a href="#ecosystem">Platform</a>
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
  );
}
