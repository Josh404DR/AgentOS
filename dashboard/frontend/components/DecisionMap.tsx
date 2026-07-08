"use client";

import { useCallback, useState } from "react";
import {
  ReactFlow,
  Node,
  Edge,
  Background,
  Controls,
  MiniMap,
  NodeProps,
  Handle,
  Position,
  useNodesState,
  useEdgesState,
} from "@xyflow/react";
import GovernanceStatus from "@/components/GovernanceStatus";
// CSS is imported globally in app/globals.css

// ─── Node types ───────────────────────────────────────────
type NodeKind = "start" | "event" | "decision" | "open" | "blocked";

interface NodeData extends Record<string, unknown> {
  label: string;
  sub?: string;
  kind: NodeKind;
  date?: string;
  detail?: string;
}

const kindStyle: Record<NodeKind, { bg: string; border: string; text: string; badge: string }> = {
  start:    { bg: "bg-purple-900", border: "border-purple-500", text: "text-purple-100", badge: "bg-purple-500" },
  event:    { bg: "bg-zinc-800",   border: "border-zinc-600",   text: "text-zinc-100",   badge: "bg-zinc-500" },
  decision: { bg: "bg-blue-900",   border: "border-blue-500",   text: "text-blue-100",   badge: "bg-blue-500" },
  open:     { bg: "bg-emerald-900",border: "border-emerald-500",text: "text-emerald-100", badge: "bg-emerald-500" },
  blocked:  { bg: "bg-red-900",    border: "border-red-500",    text: "text-red-100",    badge: "bg-red-500" },
};

const kindLabel: Record<NodeKind, string> = {
  start:    "起點",
  event:    "事件",
  decision: "決策",
  open:     "開放選項",
  blocked:  "暫緩",
};

function CustomNode({ data, selected }: NodeProps<Node<NodeData>>) {
  const s = kindStyle[data.kind];
  return (
    <div
      className={`
        ${s.bg} ${s.border} ${s.text}
        border-2 rounded-xl px-4 py-3 min-w-[180px] max-w-[240px]
        shadow-lg cursor-pointer transition-all
        ${selected ? "ring-2 ring-white ring-offset-1 ring-offset-zinc-950" : ""}
      `}
    >
      <Handle type="target" position={Position.Top} className="!bg-zinc-600 !w-2 !h-2" />
      <div className="flex items-center gap-2 mb-1">
        <span className={`text-[9px] font-bold uppercase px-1.5 py-0.5 rounded ${s.badge} text-white`}>
          {kindLabel[data.kind]}
        </span>
        {data.date && <span className="text-[9px] text-zinc-400 ml-auto">{data.date}</span>}
      </div>
      <p className="text-xs font-semibold leading-snug">{data.label}</p>
      {data.sub && <p className="text-[10px] opacity-70 mt-0.5 leading-snug">{data.sub}</p>}
      <Handle type="source" position={Position.Bottom} className="!bg-zinc-600 !w-2 !h-2" />
    </div>
  );
}

const nodeTypes = { custom: CustomNode };

// ─── Data ─────────────────────────────────────────────────
const initialNodes: Node<NodeData>[] = [
  { id: "josh", type: "custom", position: { x: 430, y: 0 },
    data: { kind: "start", label: "Josh 提出自然語言需求", sub: "唯一治理 owner 與人工決策者", date: "現在",
      detail: "Josh 決定需求、刪除、外部行動與治理方向；其他角色不得自行擴張權限。" } },
  { id: "hermes", type: "custom", position: { x: 430, y: 130 },
    data: { kind: "event", label: "Hermes 接收意圖並建立工單", sub: "Telegram 入口 · 不負責實作",
      detail: "Hermes 將自然語言轉成可稽核 TASK.md，綁定 dispatch ID、治理版本與雜湊。" } },
  { id: "gate", type: "custom", position: { x: 430, y: 260 },
    data: { kind: "decision", label: "治理 Gate + 規則分類", sub: "aligned 才可執行 · 零模型判斷",
      detail: "先執行 assert_governance_ready.ps1，再由 RuleBasedClassifier 分成 Simple、Complex 或 Risky。" } },

  { id: "simple", type: "custom", position: { x: 20, y: 410 },
    data: { kind: "decision", label: "Simple Task", sub: "範圍明確、低風險、無複雜依賴",
      detail: "直接建立 Claude Worker 工單，不需要 Codex Plan。" } },
  { id: "complex", type: "custom", position: { x: 430, y: 410 },
    data: { kind: "decision", label: "Complex Task", sub: "多步驟、跨元件或存在依賴",
      detail: "先由 Codex Plan 拆成父／子工單、依賴順序與驗收條件；Codex Plan 不實作。" } },
  { id: "risky", type: "custom", position: { x: 840, y: 410 },
    data: { kind: "blocked", label: "Risky Task", sub: "停止自動執行，等待 Josh",
      detail: "部署、外部寫入、刪除、憑證、金流或重大核心重構必須先進 ESCALATION_QUEUE。" } },

  { id: "codex-plan", type: "custom", position: { x: 430, y: 550 },
    data: { kind: "event", label: "Codex Plan 拆解工單", sub: "只規劃父子節點與 acceptance criteria",
      detail: "產生確定性的 dependency_order 與 depends_on，不修改 workspace。" } },
  { id: "escalation", type: "custom", position: { x: 840, y: 550 },
    data: { kind: "blocked", label: "ESCALATION_QUEUE", sub: "統一承接所有人工決策",
      detail: "Risky、分類不明、兩輪仍失敗或 NEEDS_HUMAN_DECISION 都寫入獨立 JSON，等待 Josh。" } },
  { id: "queue", type: "custom", position: { x: 250, y: 700 },
    data: { kind: "event", label: "Queue 依依賴順序排程", sub: "只做確定性狀態轉移，不做 AI 決策",
      detail: "Queue 啟動 ready 節點、維護依賴與重試輪次，不呼叫模型分類。" } },
  { id: "antigravity", type: "custom", position: { x: -140, y: 840 },
    data: { kind: "open", label: "Antigravity 低風險輔助", sub: "選擇性 · 脫敏交接包 · OUTPUTS only",
      detail: "只適用研究、文件、靜態檢查與測試；不得成為核心實作者或最終 verifier。" } },
  { id: "claude", type: "custom", position: { x: 250, y: 840 },
    data: { kind: "event", label: "Claude Worker 實作", sub: "依工單核准範圍修改 workspace",
      detail: "Claude 是預設實作者與修正者，必須保留無關變更並產出可驗證 artifacts。" } },
  { id: "artifacts", type: "custom", position: { x: 250, y: 980 },
    data: { kind: "event", label: "產出交付證據", sub: "RESULT + SCOPED_DIFF + TEST_RESULT",
      detail: "完成報告必須包含實際變更、測試證據、未解風險與 artifact 路徑。" } },
  { id: "verify", type: "custom", position: { x: 250, y: 1120 },
    data: { kind: "decision", label: "Codex Blind Verify", sub: "全新 session · read-only · 不含 Plan reasoning",
      detail: "只接收 task ticket、acceptance criteria、diff、test result 與 delivery artifact。" } },

  { id: "pass", type: "custom", position: { x: -80, y: 1270 },
    data: { kind: "open", label: "PASS", sub: "驗收條件全部達成",
      detail: "寫入 append-only METRICS_LOG，接著收斂父工單與整條工作流。" } },
  { id: "fail", type: "custom", position: { x: 300, y: 1270 },
    data: { kind: "decision", label: "FAIL：交回 Claude 修正", sub: "最多兩輪，不自行擴張 scope",
      detail: "每輪產生新的 revision 工單與新的獨立 Codex Verify；超過兩輪即升級人工決策。" } },
  { id: "human", type: "custom", position: { x: 670, y: 1270 },
    data: { kind: "blocked", label: "NEEDS_HUMAN_DECISION", sub: "證據不足或需 Josh 選擇",
      detail: "不得猜測或宣稱完成，直接寫入 ESCALATION_QUEUE。" } },
  { id: "metrics", type: "custom", position: { x: -80, y: 1410 },
    data: { kind: "event", label: "Metrics + 根工單收斂", sub: "completed 只由實際 artifacts 證明",
      detail: "記錄 verifier、verdict、retry_count、duration 與可取得的 token；未知值填 unknown。" } },
  { id: "report", type: "custom", position: { x: 250, y: 1550 },
    data: { kind: "start", label: "Hermes 回報 Josh", sub: "真正 completed 或具體待決策事項",
      detail: "Hermes 只整理狀態與證據，不取代實作者、verifier 或 source of truth。" } },
];

const initialEdges: Edge[] = [
  { id: "e1", source: "josh", target: "hermes", animated: true, style: { stroke: "#7c3aed" } },
  { id: "e2", source: "hermes", target: "gate", animated: true, style: { stroke: "#3b82f6" } },
  { id: "e3", source: "gate", target: "simple", style: { stroke: "#10b981" }, label: "Simple" },
  { id: "e4", source: "gate", target: "complex", style: { stroke: "#3b82f6" }, label: "Complex" },
  { id: "e5", source: "gate", target: "risky", style: { stroke: "#ef4444" }, label: "Risky" },
  { id: "e6", source: "simple", target: "queue", style: { stroke: "#10b981" } },
  { id: "e7", source: "complex", target: "codex-plan", style: { stroke: "#3b82f6" } },
  { id: "e8", source: "codex-plan", target: "queue", style: { stroke: "#3b82f6" } },
  { id: "e9", source: "risky", target: "escalation", animated: true, style: { stroke: "#ef4444" } },
  { id: "e10", source: "queue", target: "claude", animated: true, style: { stroke: "#a855f7" } },
  { id: "e11", source: "queue", target: "antigravity", style: { stroke: "#10b981", strokeDasharray: "5,5" }, label: "選擇性" },
  { id: "e12", source: "claude", target: "artifacts", style: { stroke: "#6b7280" } },
  { id: "e13", source: "antigravity", target: "artifacts", style: { stroke: "#10b981", strokeDasharray: "5,5" } },
  { id: "e14", source: "artifacts", target: "verify", animated: true, style: { stroke: "#3b82f6" } },
  { id: "e15", source: "verify", target: "pass", style: { stroke: "#10b981" }, label: "PASS" },
  { id: "e16", source: "verify", target: "fail", style: { stroke: "#f59e0b" }, label: "FAIL" },
  { id: "e17", source: "verify", target: "human", style: { stroke: "#ef4444" }, label: "HUMAN" },
  { id: "e18", source: "fail", target: "claude", animated: true, style: { stroke: "#f59e0b", strokeDasharray: "5,5" }, label: "≤ 2 rounds" },
  { id: "e19", source: "fail", target: "escalation", style: { stroke: "#ef4444" }, label: "> 2 rounds" },
  { id: "e20", source: "human", target: "escalation", style: { stroke: "#ef4444" } },
  { id: "e21", source: "pass", target: "metrics", style: { stroke: "#10b981" } },
  { id: "e22", source: "metrics", target: "report", animated: true, style: { stroke: "#7c3aed" } },
  { id: "e23", source: "escalation", target: "report", style: { stroke: "#ef4444", strokeDasharray: "5,5" } },
];

// ─── Main component ────────────────────────────────────────
export default function DecisionMap() {
  const [nodes, , onNodesChange] = useNodesState(initialNodes);
  const [edges, , onEdgesChange] = useEdgesState(initialEdges);
  const [selected, setSelected] = useState<NodeData | null>(null);

  const onNodeClick = useCallback((_: unknown, node: Node<NodeData>) => {
    setSelected(node.data);
  }, []);

  const onPaneClick = useCallback(() => setSelected(null), []);

  return (
    <div className="flex h-full gap-0">
      {/* Flow canvas */}
      <div className="flex-1 relative">
        <GovernanceStatus />
        <ReactFlow
          nodes={nodes}
          edges={edges}
          onNodesChange={onNodesChange}
          onEdgesChange={onEdgesChange}
          onNodeClick={onNodeClick}
          onPaneClick={onPaneClick}
          nodeTypes={nodeTypes}
          fitView
          fitViewOptions={{ padding: 0.2 }}
          minZoom={0.3}
          maxZoom={2}
          className="bg-zinc-950"
        >
          <Background color="#27272a" gap={20} />
          <Controls className="[&>button]:bg-zinc-800 [&>button]:border-zinc-700 [&>button]:text-zinc-300" />
          <MiniMap
            nodeColor={(n) => {
              const kind = (n.data as NodeData)?.kind;
              return kind === "open" ? "#10b981" : kind === "decision" ? "#3b82f6" : kind === "start" ? "#7c3aed" : kind === "blocked" ? "#ef4444" : "#52525b";
            }}
            className="!bg-zinc-900 !border-zinc-700"
          />
        </ReactFlow>

        {/* Legend */}
        <div className="absolute bottom-16 left-3 bg-zinc-900/90 border border-zinc-800 rounded-lg px-3 py-2 flex flex-col gap-1 text-[10px]">
          {(Object.entries(kindStyle) as [NodeKind, typeof kindStyle[NodeKind]][]).map(([k, s]) => (
            <div key={k} className="flex items-center gap-1.5">
              <span className={`w-2.5 h-2.5 rounded-sm ${s.badge}`} />
              <span className="text-zinc-400">{kindLabel[k]}</span>
            </div>
          ))}
        </div>
      </div>

      {/* Detail panel */}
      <div
        className={`
          border-l border-zinc-800 bg-zinc-900 flex flex-col transition-all duration-200 overflow-hidden
          ${selected ? "w-64" : "w-0"}
        `}
      >
        {selected && (
          <div className="p-4 flex flex-col gap-3">
            <div className="flex items-start justify-between gap-2">
              <div>
                <span className={`text-[9px] font-bold uppercase px-1.5 py-0.5 rounded ${kindStyle[selected.kind].badge} text-white`}>
                  {kindLabel[selected.kind]}
                </span>
                {selected.date && <span className="text-[10px] text-zinc-500 ml-2">{selected.date}</span>}
              </div>
              <button onClick={() => setSelected(null)} className="text-zinc-600 hover:text-zinc-300 text-xs">✕</button>
            </div>
            <h3 className="text-sm font-semibold text-zinc-100 leading-snug">{selected.label}</h3>
            {selected.sub && <p className="text-xs text-zinc-400">{selected.sub}</p>}
            {selected.detail && (
              <p className="text-xs text-zinc-300 leading-relaxed border-t border-zinc-800 pt-3">
                {selected.detail}
              </p>
            )}
          </div>
        )}
      </div>
    </div>
  );
}
