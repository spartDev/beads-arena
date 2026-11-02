// arena-vitals: flow and learning metrics computed from Beads, read-only.
//
// Usage: arena-vitals [--since 30d] [--json] [--oneline] [--max-history 150]
//
// Every metric is a proxy built from bd's own timestamps. Definitions are printed with the
// numbers so nobody mistakes a proxy for the real thing.

import { execFileSync } from "node:child_process";

type Bead = {
  readonly id: string;
  readonly title: string;
  readonly issue_type: string;
  readonly status: string;
  readonly created_at: string;
  readonly updated_at?: string;
  readonly started_at?: string;
  readonly closed_at?: string;
  readonly close_reason?: string;
  readonly external_ref?: string;
  readonly parent?: string;
  readonly labels?: readonly string[] | null;
  readonly await_type?: string | null;
  readonly dependent_count?: number;
  // `bd show` returns full beads with dependency_type; `bd list` returns edges with type.
  readonly dependencies?: readonly (Partial<Bead> & { readonly dependency_type?: string; readonly type?: string })[];
};

type HistoryEntry = { readonly CommitDate: string; readonly Issue: Pick<Bead, "status"> };

type Stat = { readonly n: number; readonly median: number | null; readonly p85: number | null };

type Metric = { readonly key: string; readonly label: string; readonly definition: string; readonly hours: Stat };

type Report = {
  readonly window: { readonly since: string; readonly days: number };
  readonly flow: Readonly<Record<string, number>>;
  readonly pit: number;
  readonly metrics: readonly Metric[];
  readonly learning: { readonly filed: number; readonly closed: number; readonly structuralShare: number | null };
  readonly discoveredRatio: number | null;
};

// ---------- IO at the edge ----------

const bd = <T,>(args: readonly string[]): T => {
  const out = execFileSync("bd", [...args, "--json"], { encoding: "utf8", maxBuffer: 64 * 1024 * 1024 });
  const parsed: unknown = JSON.parse(out || "null");
  return (parsed ?? []) as T;
};

const showOne = (id: string): Bead | undefined => {
  const r = bd<Bead[] | Bead>(["show", id]);
  return Array.isArray(r) ? r[0] : r;
};

// ---------- pure helpers ----------

const HOUR = 3_600_000;
const WORK_TYPES = new Set(["task", "bug", "feature", "chore", "story", "spike", "decision"]);

const t = (iso?: string | null): number | null => (iso ? Date.parse(iso) : null);

const hoursBetween = (from?: string | null, to?: string | null): number | null => {
  const a = t(from);
  const b = t(to);
  return a !== null && b !== null && b >= a ? (b - a) / HOUR : null;
};

const quantile = (sorted: readonly number[], q: number): number | null =>
  sorted.length === 0 ? null : sorted[Math.min(sorted.length - 1, Math.floor(q * (sorted.length - 1) + 0.5))];

const stat = (values: readonly (number | null)[]): Stat => {
  const xs = values.filter((v): v is number => v !== null).sort((a, b) => a - b);
  return { n: xs.length, median: quantile(xs, 0.5), p85: quantile(xs, 0.85) };
};

const hasLabel = (b: Bead, label: string): boolean => (b.labels ?? []).includes(label);

const edgeType = (d: { readonly dependency_type?: string; readonly type?: string }): string | undefined => d.dependency_type ?? d.type;

const inWindow = (sinceMs: number) => (iso?: string | null): boolean => (t(iso) ?? 0) >= sinceMs;

// Poured formula steps have ids like ar-mol-x (no dot); tickets created under a step are ar-mol-x.1.
// Wisp steps (rounds, bouts, patrols) are never tickets.
const FORMULA_STEP_ID = /-mol-[a-z0-9]+$/;
const isTicket = (b: Bead): boolean =>
  WORK_TYPES.has(b.issue_type) && !b.id.includes("-wisp-") && !FORMULA_STEP_ID.test(b.id);

const parseDays = (s: string): number => {
  const m = /^(\d+)d$/.exec(s);
  if (!m) throw new Error(`--since expects <N>d, got ${s}`);
  return Number(m[1]);
};

const argValue = (argv: readonly string[], flag: string, fallback: string): string => {
  const i = argv.indexOf(flag);
  return i >= 0 && argv[i + 1] ? argv[i + 1] : fallback;
};

// ---------- metrics (pure, given fetched data) ----------

// closedGates must come from `bd show` (gate list rows carry no parent and no closed_at).
const timeToReadySeason = (seasons: readonly Bead[], closedGates: readonly Bead[]): (number | null)[] =>
  seasons.map((s) => {
    const approval = closedGates.find((g) => g.parent === s.id && /approves the .* breakdown/.test(g.title));
    return approval ? hoursBetween(s.created_at, approval.closed_at) : null;
  });

const timeToReadyTicket = (tickets: readonly Bead[], events: readonly Bead[]): (number | null)[] =>
  tickets.map((tk) => {
    const ready = events
      .filter((e) => e.parent === tk.id && /triage → ready-for-agent/.test(e.title))
      .map((e) => e.created_at)
      .sort()[0];
    return ready ? hoursBetween(tk.created_at, ready) : null;
  });

const firstStatusAt = (history: readonly HistoryEntry[], status: string): string | undefined =>
  history
    .filter((h) => h.Issue?.status === status)
    .map((h) => new Date(h.CommitDate).toISOString())
    .sort()[0];

const humanWait = (gate: Bead): number | null => {
  const readyAt = (gate.dependencies ?? [])
    .filter((d) => edgeType(d) === "blocks")
    .map((d) => d.closed_at)
    .filter((x): x is string => Boolean(x))
    .sort()
    .at(-1);
  return hoursBetween(readyAt ?? gate.created_at, gate.closed_at);
};

// ---------- assemble ----------

const build = (argv: readonly string[]): Report => {
  const sinceArg = argValue(argv, "--since", "30d");
  const days = parseDays(sinceArg);
  const sinceMs = Date.now() - days * 24 * HOUR;
  const recent = inWindow(sinceMs);
  const maxHistory = Number(argValue(argv, "--max-history", "150"));

  const all = bd<Bead[]>(["list", "--all", "--limit", "0"]);
  const gates = bd<Bead[]>(["gate", "list", "--all"]);
  const tickets = all.filter(isTicket);
  const events = all.filter((b) => b.issue_type === "event");
  const seasons = all.filter((b) => b.issue_type === "molecule" && b.title === "arena-season");

  const flow = tickets
    .filter((b) => b.status !== "closed" || recent(b.closed_at))
    .reduce<Record<string, number>>((acc, b) => ({ ...acc, [b.status]: (acc[b.status] ?? 0) + 1 }), {});

  const blocked = new Set(bd<Bead[]>(["blocked"]).map((b) => b.id));
  // A gate still waiting on unfinished work is not the human's yet.
  const openHumanGates = gates.filter((g) => g.status === "open" && (g.await_type === "human" || !g.await_type) && !blocked.has(g.id));
  const pit = openHumanGates.length + tickets.filter((b) => b.status !== "closed" && hasLabel(b, "triage:ready-for-human")).length;

  const merged = tickets.filter((b) => b.status === "closed" && recent(b.closed_at) && /merged/i.test(b.close_reason ?? ""));
  const withPr = merged.filter((b) => (b.external_ref ?? "").startsWith("gh-")).slice(0, maxHistory);
  const inReviewAt = new Map(withPr.map((b) => [b.id, firstStatusAt(bd<HistoryEntry[]>(["history", b.id]), "in_review")] as const));

  const closedHumanGates = gates
    .filter((g) => g.status === "closed" && (g.await_type === "human" || !g.await_type) && recent(g.updated_at))
    .slice(0, maxHistory)
    .map((g) => showOne(g.id))
    .filter((g): g is Bead => g !== undefined && recent(g.closed_at));

  const learning = all.filter((b) => hasLabel(b, "learning"));
  const learningRecent = learning.filter((b) => recent(b.created_at));
  const learningClosed = learning.filter((b) => b.status === "closed" && recent(b.closed_at));
  const createdRecent = tickets.filter((b) => recent(b.created_at));
  const discovered = createdRecent.filter((b) => (b.dependencies ?? []).some((d) => edgeType(d) === "discovered-from"));

  const metrics: Metric[] = [
    {
      key: "time_to_ready_season",
      label: "Time-to-Ready (season)",
      definition: "season poured until the human approved its ticket breakdown: idea to agent-ready backlog",
      hours: stat(timeToReadySeason(seasons.filter((s) => recent(s.created_at)), closedHumanGates)),
    },
    {
      key: "time_to_ready_ticket",
      label: "Time-to-Ready (ticket)",
      definition: "ticket created until its first triage → ready-for-agent event (tickets that went through triage)",
      hours: stat(timeToReadyTicket(createdRecent, events)),
    },
    {
      key: "intent_to_merge",
      label: "Intent-to-Merge",
      definition: "claim (started_at) until close with a merged PR",
      hours: stat(merged.map((b) => hoursBetween(b.started_at, b.closed_at))),
    },
    {
      key: "build_time",
      label: "Build time",
      definition: "claim until the PR opened (first in_review status)",
      hours: stat(withPr.map((b) => hoursBetween(b.started_at, inReviewAt.get(b.id)))),
    },
    {
      key: "review_latency",
      label: "Review latency",
      definition: "PR opened until merged",
      hours: stat(withPr.map((b) => hoursBetween(inReviewAt.get(b.id), b.closed_at))),
    },
    {
      key: "human_wait",
      label: "Human wait",
      definition: "human gate unblocked (last blocker closed) until the human resolved it",
      hours: stat(closedHumanGates.map(humanWait)),
    },
    {
      key: "learning_velocity",
      label: "Learning velocity",
      definition: "learning bead filed until closed with its check proven",
      hours: stat(learningClosed.map((b) => hoursBetween(b.created_at, b.closed_at))),
    },
  ];

  return {
    window: { since: new Date(sinceMs).toISOString(), days },
    flow,
    pit,
    metrics,
    learning: {
      filed: learningRecent.length,
      closed: learningClosed.length,
      structuralShare: learningClosed.length ? learningClosed.filter((b) => hasLabel(b, "learning:structural")).length / learningClosed.length : null,
    },
    discoveredRatio: createdRecent.length ? discovered.length / createdRecent.length : null,
  };
};

// ---------- render ----------

const fmtH = (h: number | null): string =>
  h === null ? "n/a" : h < 1 ? `${Math.round(h * 60)}m` : h < 48 ? `${h.toFixed(1)}h` : `${(h / 24).toFixed(1)}d`;

const fmtPct = (x: number | null): string => (x === null ? "n/a" : `${Math.round(x * 100)}%`);

const markdown = (r: Report): string =>
  [
    `# Arena vitals, last ${r.window.days} days`,
    "",
    `Flow: ${Object.entries(r.flow).map(([k, v]) => `${k} ${v}`).join(", ") || "no tickets"}. Pit: ${r.pit} waiting on the human.`,
    "",
    "| Metric | Median | p85 | n | Definition (proxy) |",
    "|---|---|---|---|---|",
    ...r.metrics.map((m) => `| ${m.label} | ${fmtH(m.hours.median)} | ${fmtH(m.hours.p85)} | ${m.hours.n} | ${m.definition} |`),
    "",
    `Learning: ${r.learning.filed} lessons filed, ${r.learning.closed} closed, ${fmtPct(r.learning.structuralShare)} encoded as automated checks.`,
    `Discovered work: ${fmtPct(r.discoveredRatio)} of new tickets were found during other work (hidden scope).`,
  ].join("\n");

const oneline = (r: Report): string => {
  const m = Object.fromEntries(r.metrics.map((x) => [x.key, x.hours.median]));
  return `arena ${r.window.days}d | pit ${r.pit} | TTR ${fmtH(m.time_to_ready_season ?? null)} | ITM ${fmtH(m.intent_to_merge ?? null)} | review ${fmtH(m.review_latency ?? null)} | human wait ${fmtH(m.human_wait ?? null)} | LV ${fmtH(m.learning_velocity ?? null)}`;
};

const main = (argv: readonly string[]): void => {
  const report = build(argv);
  const out = argv.includes("--json") ? JSON.stringify(report, null, 2) : argv.includes("--oneline") ? oneline(report) : markdown(report);
  process.stdout.write(`${out}\n`);
};

main(process.argv.slice(2));
