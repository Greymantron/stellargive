# Stress Test Findings: High-Volume Parallel Donations

Conducted on: `2026-06-01T16:16:27.576Z`
Target Contract ID: `CCG3QSVNUFTZGB56HZN4L6YTWOPTMR3PVG6EU7VP7MDV2QKRKFZ2REHT`

---

## 1. Executive Summary

| Metric | Value |
|---|---|
| **Total Transactions Sent** | 100 |
| **Successful Inclusions** | 1 (1.00%) |
| **Failed Inclusions** | 99 (99.00%) |
| **Average Latency (Success)** | 5164.00 ms |

---

## 2. Root Cause Analysis: State footprint write conflicts

Our test generated **100 distinct Stellar accounts** funded via Friendbot, bypassing any sequence number (nonce) collisions. Each donor submitted their transaction concurrently.

Despite this, exactly **one transaction succeeded**, while **99 failed** with `Transaction finished with status: FAILED`.

### The Soroban State Collision Mechanism:
Stellar Soroban smart contracts use **Optimistic Concurrency Control (OCC)** based on transaction read/write footprints:
1. **Footprint Generation:** When `simulateTransaction` is run for each donation, the SDK records the exact ledger entries that the transaction will read and write. In our case, every donation reads and writes the **Campaign persistent storage entry** (to update `raised_amount`, `status`, and the sorted `top_donors` list).
2. **Ledger Application:** The transaction that gets ordered first in the ledger modifies the Campaign state, updating its storage entry version (ledger sequence).
3. **Footprint Rejection:** All subsequent concurrent transactions in the same ledger block are rejected because their footprint includes a read-version of the Campaign storage entry that is now **stale**. The ledger engine aborts them to prevent state corruption.

This is a fundamental scalability limit for stateful contract invocations on Stellar (and similar parallelized UTXO/account chains like Solana and Sui) where transactions contend for a single shared hot-spot state key.

---

## 3. Concrete Optimization Recommendations

To support high-throughput, concurrent fundraising events without failing transactions, we recommend the following two-fold optimization path:

### A. Client-Side Mitigation (Immediate)
- **Queueing & Batching:** Implement a client-side transaction queue. Instead of firing donations instantly, pace submissions or batch contributions onto the client application layer before pushing to the ledger.
- **Exponential Backoff Retries:** Automatically catch footprint write failures on the client side and retry the donation with a randomized exponential backoff (pacing submissions across subsequent ledgers, which close every ~5 seconds).

### B. Contract-Side Re-Architecture (Long-Term)
- **Sharded Balances (State Sharding):** Instead of updating a single shared Campaign total (`raised_amount`) on every donation, write each donation to a *donor-specific* persistent key (e.g., `(CampaignId, DonorAddress) -> Contribution`).
- **Deferred Accumulation:** When the campaign completes or a claim is settled, a single transaction can traverse and accumulate all sharded donor contributions, avoiding concurrent write collisions entirely during the active donation phase.
