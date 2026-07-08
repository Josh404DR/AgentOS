import streamlit as st

# Page Configuration
st.set_page_config(
    page_title="Josh Hsu - AI Engineer Resume MVP",
    page_icon="🤖",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Custom CSS
st.markdown("""
    <style>
    .main {
        background-color: #0e1117;
    }
    .stApp {
        background: linear-gradient(135deg, #0e1117 0%, #161b22 100%);
    }
    h1, h2, h3 {
        color: #3b82f6 !important;
    }
    .skill-tag {
        display: inline-block;
        padding: 4px 12px;
        border-radius: 16px;
        background: rgba(59, 130, 246, 0.1);
        color: #3b82f6;
        border: 1px solid rgba(59, 130, 246, 0.2);
        margin: 4px;
        font-size: 0.85rem;
    }
    .card {
        padding: 20px;
        border-radius: 12px;
        background: rgba(255, 255, 255, 0.03);
        border: 1px solid rgba(255, 255, 255, 0.1);
        margin-bottom: 15px;
    }
    </style>
""", unsafe_allow_html=True)

# Sidebar
with st.sidebar:
    st.title("👨‍💻 Josh Hsu")
    st.subheader("AI Product Engineer")
    st.info("📍 台灣 (Taiwan)")
    st.markdown("---")
    st.write("📫 [Email](mailto:pkg0530hsu@gmail.com)")
    st.write("🔗 [LinkedIn](#)")
    st.write("💻 [GitHub](#)")
    st.markdown("---")
    st.success("Language: 中文 (Native), English (Prof)")

# Main Content
tabs = st.tabs(["🌟 專業總覽", "🛠️ 技術棧", "💼 專業經歷", "🚀 關鍵專案"])

with tabs[0]:
    st.header("專業總覽")
    st.markdown("""
    具備深厚的 **AI 應用開發經驗**，擅長將尖端技術（如 LLM、RAG、生成式影像）轉化為可商業化的穩定產品。
    目前專注於打造工業級 AI 電商自動化工具。
    """)
    
    col1, col2, col3 = st.columns(3)
    with col1:
        st.subheader("🚀 產品化思維")
        st.write("強調斷點續傳、錯誤彈性與跨平台部署。")
    with col2:
        st.subheader("🧠 Prompt Expert")
        st.write("V6 級別結構化框架，精確控制生成品質。")
    with col3:
        st.subheader("💻 全端技術整合")
        st.write("從 Python 後端到 CustomTkinter 前端。")

with tabs[1]:
    st.header("核心技術棧")
    
    st.subheader("AI & Data Science")
    ai_skills = ["Gemini", "OpenAI API", "Prompt Engineering", "OpenCV", "Pillow", "Rembg", "ONNX", "Trino", "Pandas", "RAG"]
    st.markdown(" ".join([f'<span class="skill-tag">{s}</span>' for s in ai_skills]), unsafe_allow_html=True)
    
    st.subheader("Software Engineering")
    se_skills = ["Python", "YAML", "SQL", "Modular Design", "PyInstaller", "Git", "Aiohttp", "CI/CD", "OneDrive Sync"]
    st.markdown(" ".join([f'<span class="skill-tag">{s}</span>' for s in se_skills]), unsafe_allow_html=True)

with tabs[2]:
    st.header("專業經歷")
    st.subheader("AI 產品開發負責人 | 202X – 現在")
    
    with st.expander("🏗️ 工業級穩定性架構", expanded=True):
        st.write("- **Checkpointing**: 大規模批次處理斷點續傳，節省 30% 成本。")
        st.write("- **Error Isolation**: Retry/Backoff 機制確保單一失敗不影響整體。")
        st.write("- **Observability**: Thread-safe UI 提供即時進度與 ETA。")
        
    with st.expander("⚙️ YAML 驅動工作流"):
        st.write("- **Decoupling**: 邏輯與配置分離，提升擴展性。")
        st.write("- **Admin Panel**: 內建編輯器使非技術人員可調整流程。")
        
    with st.expander("🎨 自動化影像處理"):
        st.write("- **Pipelines**: Main/Detail Pipeline 整合 CDN 上傳。")
        st.write("- **Dedup**: 電腦視覺去重技術，優化儲存成本。")

with tabs[3]:
    st.header("關鍵專案")
    
    col1, col2 = st.columns(2)
    with col1:
        st.markdown("""
        <div class="card">
            <h4>🧙‍♂️ AI_Tool_Wizard</h4>
            <p>將複雜 Python 環境封裝為一鍵執行的 EXE。</p>
            <p><b>特色：</b> 自動更新、Smoke Test 機制。</p>
        </div>
        """, unsafe_allow_html=True)
        
    with col2:
        st.markdown("""
        <div class="card">
            <h4>📚 Sandbox-RAG</h4>
            <p>基於檢索增強生成的企業內部問答平台。</p>
            <p><b>特色：</b> 高效檢索、結構化輸出。</p>
        </div>
        """, unsafe_allow_html=True)

    st.markdown("---")
    st.subheader("⚡ 產品化與部署演示")
    st.info("此區塊展示 Josh 如何處理「最後一公里」的部署問題，包括 PyInstaller 封裝邏輯與類 CI/CD 管線。")
    
st.markdown("---")
st.caption("© 2026 Josh Hsu | Built with Streamlit")
