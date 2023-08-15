<div align="center">

  <h1><code>Standard</code></h1>

  <p>
    <strong>A monorepo for Standard Protocol contracts</strong>
  </p>

  <p>
    <a href="https://github.com/standardweb3/standardweb3/standard-2.0-contracts"><img alt="Bridge Version" src="https://img.shields.io/github/package-json/v/standardweb3/standard-2.0-contracts"></a>
    <a href="https://t.me/standard_protocol"><img alt="Telegram Chat" src="https://img.shields.io/badge/telegram-chat-blue?logo=telegram"></a>
  </p>
</div>

## What is Standard Protocol?
![overview](./media/overview.png)

Standard Protocol operates as a comprehensive, all-encompassing application designed specifically for the blockchain universe. Its primary role is to provide a foundation or starting point for newly developed blockchain spaces, ensuring they have the necessary tools and environment to establish a thriving and dynamic ecosystem. The unique aspect of Standard is its ability to function as a unified execution layer empowering its users with fully decentralized system. This unified layer is a game-changer as it bridges the gap between different blockchain systems, enabling seamless interoperability among them. In simpler terms, regardless of which blockchain you're working on or interacting with, Standard ensures they can communicate and operate with each other without complications, all on your control.

## Apps

The Standard super app is a self-sovereign financial platform that empowers individuals in the web3.0 ecosystem. It combines various integrated apps, each tailored to enhance different aspects of financial management and trading. Here's how Standard streamlines the digital financial experience:

---
1. **Managing Credit and Governance with [SABT](./contracts/sabt/README.md)**: The SABT app serves as a self-custodial account within the Standard platform, storing credit that revolves around other integrated apps. It allows users to manage their credit lines effectively, facilitating seamless transactions and financial operations across the ecosystem. In addition, the credits earned through SABT can be utilized in governance processes within the platform, enabling real users to influence the direction and evolution of the system. With an active subscription status, SABT credit holders can even exchange their credits with the company's revenue as part of Standard's unique revenue-sharing business model, further integrating them into the financial successes and opportunities of the platform.
---
2. **Trading Digital Assets with [SAFEX](./contracts/safex/README.md)**: Standard offers the SAFEX app, which allows users to trade digital assets at their preferred prices and quantities. Whether you're a seasoned trader or new to the digital market, SAFEX offers the tools to buy and sell with precision and control.
---
3. **Financing Digital Assets with a Shared Unit of Account with [SAFU](./contracts/safu/README.md)**: The SAFU app within Standard enables users to select their preferred unit of account for their finance interacting with its own reserve currency system. Independent from fixed exchange rate with the US dollar, SAFU builds a monetary system relying on both sovereign monetary policy with controlled capital flow. This unique feature allows for tailored financial planning and management, aligning with personal preferences and strategies.
---
4. **Leveraging and Deleveraging Wealth with [SAIL](./contracts/sail/README.md)**: If you're looking to leverage (increase exposure using borrowed capital) or deleverage (reduce exposure) your wealth based on future economic cycles, the SAIL app offers a streamlined solution. This functionality provides users with the ability to strategically position their assets in accordance with market predictions.
---
Collectively, these apps, including **SABT** for credit management and governance, **SAFEX** for digital asset trading, **SAFU** for unit of account selection, and **SAIL** for leveraging and deleveraging strategies, create a cohesive ecosystem within the Standard super app. Together, they offer a wide range of financial tools and capabilities, providing a comprehensive solution for navigating the complex landscape of digital finance. Whether managing credit, trading digital assets, selecting a monetary unit, or leveraging wealth, Standard equips users with the tools they need to take control of their financial futures. It's more than just a platform; it's a gateway to the future of decentralized economic empowerment.

# The Standard Super App: Your Web3.0 Financial Gateway

The **Standard super app** stands as a pinnacle in the web3.0 ecosystem, bestowing individuals with a suite of integrated apps. Each app is meticulously designed to elevate diverse financial management and trading needs. Here's an insight into what each facet of Standard offers:

---

### 1. [SABT: Your Financial Steward](./contracts/sabt/README.md)

- **Core Functionality**: Acts as your self-managed account on the Standard platform.
- **Benefits**:
  - Houses credits that synergize with other apps within the platform.
  - Enables seamless transactions and financial mechanics.
  - Lets users employ credits for platform governance, actively shaping its trajectory.
  - Active subscribers can swap credits for a slice of the company's revenue, a testimony to Standard's revolutionary revenue-sharing model.

---

### 2. [SAFEX: The Digital Marketplace](./contracts/safex/README.md)

- **Core Functionality**: A trusted zone to trade digital assets.
- **Benefits**:
  - Execute trades at user-defined prices and scales.
  - Equipped with tools that cater to both novices and veterans in digital trading.

---

### 3. [SAFU: Monetary Standardization](./contracts/safu/README.md)

- **Core Functionality**: Grants users the liberty to adopt a preferred financial standard.
- **Benefits**:
  - Operates with an autonomous reserve currency system, sidestepping traditional exchange rate constraints.
  - Combines autonomous monetary blueprints with monitored capital flow for customizable financial strategizing.

---

### 4. [SAIL: Navigating Economic Currents](./contracts/sail/README.md)

- **Core Functionality**: A strategic toolset for dynamic wealth management.
- **Benefits**:
  - Users can amplify or dilute their asset exposure in line with anticipated economic trends.
  - Provides actionable insights for optimal asset placement.

---

In essence, the **Standard super app** unifies **SABT** (governance & credit management), **SAFEX** (digital trading), **SAFU** (financial standardization), and **SAIL** (wealth strategy) into a cohesive ecosystem. This ensemble delivers a holistic suite of financial instruments, streamlining the intricacies of digital finance. With Standard, users are equipped, empowered, and emboldened to architect their financial destinies. It's not merely a platform but a beacon heralding the dawn of decentralized economic empowerment.


## Docs

For more information on the concepts and how each app works, visit the official gitbook documentation.

<a href="https://docs.standardweb3.com" target="_blank" style="background-color:#3F3F3F; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px;">Go to Official Documentation</a>


## Security

### Tests
[Contract Test Directory](./test)

### Audits
[Hacken in 2023](./audits/hacken-2023)

## Licensing

The primary license for the codes in this repo are the Business Source License 1.1 (`BUSL-1.1`), see [`LICENSE`](./LICENSE). 
