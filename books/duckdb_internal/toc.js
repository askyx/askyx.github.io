// Populate the sidebar
//
// This is a script, and not included directly in the page, to control the total size of the book.
// The TOC contains an entry for each page, so if each page includes a copy of the TOC,
// the total size of the page becomes O(n**2).
class MDBookSidebarScrollbox extends HTMLElement {
    constructor() {
        super();
    }
    connectedCallback() {
        this.innerHTML = '<ol class="chapter"><li class="chapter-item expanded affix "><a href="index.html">Internal of duckdb</a></li><li class="chapter-item expanded affix "><li class="part-title">Before you read</li><li class="chapter-item expanded "><a href="before/installation.html"><strong aria-hidden="true">1.</strong> 安装</a></li><li class="chapter-item expanded "><a href="before/structure.html"><strong aria-hidden="true">2.</strong> 架构</a></li><li class="chapter-item expanded "><a href="before/debugging.html"><strong aria-hidden="true">3.</strong> 调试技巧</a></li><li class="chapter-item expanded affix "><li class="part-title">Internal</li><li class="chapter-item expanded "><a href="internal/parser/index.html"><strong aria-hidden="true">4.</strong> parser</a></li><li><ol class="section"><li class="chapter-item expanded "><a href="internal/parser/standard_sql.html"><strong aria-hidden="true">4.1.</strong> 标准SQL支持</a></li><li class="chapter-item expanded "><a href="internal/parser/extended_sql.html"><strong aria-hidden="true">4.2.</strong> 扩展SQL支持</a></li><li class="chapter-item expanded "><a href="internal/parser/implementation.html"><strong aria-hidden="true">4.3.</strong> parser实现</a></li></ol></li><li class="chapter-item expanded "><a href="internal/binder/index.html"><strong aria-hidden="true">5.</strong> binder</a></li><li class="chapter-item expanded "><a href="internal/optimizer/index.html"><strong aria-hidden="true">6.</strong> optimizer</a></li><li><ol class="section"><li class="chapter-item expanded "><a href="internal/optimizer/overview.html"><strong aria-hidden="true">6.1.</strong> logical plan</a></li><li class="chapter-item expanded "><a href="internal/optimizer/query_optimization.html"><strong aria-hidden="true">6.2.</strong> 查询优化</a></li><li><ol class="section"><li class="chapter-item expanded "><a href="internal/optimizer/expression_optimization.html"><strong aria-hidden="true">6.2.1.</strong> 表达式优化</a></li><li class="chapter-item expanded "><a href="internal/optimizer/subquery_optimization.html"><strong aria-hidden="true">6.2.2.</strong> 子查询优化</a></li><li class="chapter-item expanded "><a href="internal/optimizer/join_optimization.html"><strong aria-hidden="true">6.2.3.</strong> join优化</a></li></ol></li><li class="chapter-item expanded "><a href="internal/optimizer/statistics.html"><strong aria-hidden="true">6.3.</strong> 统计信息</a></li><li class="chapter-item expanded "><a href="internal/optimizer/query_plan_generation.html"><strong aria-hidden="true">6.4.</strong> 查询计划生成</a></li></ol></li><li class="chapter-item expanded "><a href="internal/executor/index.html"><strong aria-hidden="true">7.</strong> executor</a></li><li><ol class="section"><li class="chapter-item expanded "><a href="internal/executor/overview.html"><strong aria-hidden="true">7.1.</strong> physical plan</a></li><li class="chapter-item expanded "><a href="internal/executor/pipeline.html"><strong aria-hidden="true">7.2.</strong> pipeline</a></li><li class="chapter-item expanded "><a href="internal/executor/vectorized_execution.html"><strong aria-hidden="true">7.3.</strong> vectorized execution</a></li><li class="chapter-item expanded "><a href="internal/executor/query_execution.html"><strong aria-hidden="true">7.4.</strong> 查询执行</a></li><li><ol class="section"><li class="chapter-item expanded "><a href="internal/executor/scan.html"><strong aria-hidden="true">7.4.1.</strong> scan</a></li><li class="chapter-item expanded "><a href="internal/executor/filter.html"><strong aria-hidden="true">7.4.2.</strong> filter</a></li><li class="chapter-item expanded "><a href="internal/executor/projection.html"><strong aria-hidden="true">7.4.3.</strong> projection</a></li><li class="chapter-item expanded "><a href="internal/executor/aggregate.html"><strong aria-hidden="true">7.4.4.</strong> aggregate</a></li><li class="chapter-item expanded "><a href="internal/executor/join.html"><strong aria-hidden="true">7.4.5.</strong> join</a></li><li class="chapter-item expanded "><a href="internal/executor/sort.html"><strong aria-hidden="true">7.4.6.</strong> sort</a></li><li class="chapter-item expanded "><a href="internal/executor/limit.html"><strong aria-hidden="true">7.4.7.</strong> limit</a></li><li class="chapter-item expanded "><a href="internal/executor/union.html"><strong aria-hidden="true">7.4.8.</strong> union</a></li><li class="chapter-item expanded "><a href="internal/executor/subquery.html"><strong aria-hidden="true">7.4.9.</strong> subquery</a></li></ol></li></ol></li><li class="chapter-item expanded "><a href="internal/storage/index.html"><strong aria-hidden="true">8.</strong> storage</a></li><li class="chapter-item expanded "><a href="internal/extension/index.html"><strong aria-hidden="true">9.</strong> extension</a></li><li class="chapter-item expanded affix "><li class="part-title">Others</li><li class="chapter-item expanded "><a href="faq.html"><strong aria-hidden="true">10.</strong> FAQ</a></li><li class="chapter-item expanded "><a href="changelog.html"><strong aria-hidden="true">11.</strong> Changelog</a></li><li class="chapter-item expanded affix "><li class="spacer"></li><li class="chapter-item expanded affix "><a href="endding.html">The end</a></li></ol>';
        // Set the current, active page, and reveal it if it's hidden
        let current_page = document.location.href.toString().split("#")[0].split("?")[0];
        if (current_page.endsWith("/")) {
            current_page += "index.html";
        }
        var links = Array.prototype.slice.call(this.querySelectorAll("a"));
        var l = links.length;
        for (var i = 0; i < l; ++i) {
            var link = links[i];
            var href = link.getAttribute("href");
            if (href && !href.startsWith("#") && !/^(?:[a-z+]+:)?\/\//.test(href)) {
                link.href = path_to_root + href;
            }
            // The "index" page is supposed to alias the first chapter in the book.
            if (link.href === current_page || (i === 0 && path_to_root === "" && current_page.endsWith("/index.html"))) {
                link.classList.add("active");
                var parent = link.parentElement;
                if (parent && parent.classList.contains("chapter-item")) {
                    parent.classList.add("expanded");
                }
                while (parent) {
                    if (parent.tagName === "LI" && parent.previousElementSibling) {
                        if (parent.previousElementSibling.classList.contains("chapter-item")) {
                            parent.previousElementSibling.classList.add("expanded");
                        }
                    }
                    parent = parent.parentElement;
                }
            }
        }
        // Track and set sidebar scroll position
        this.addEventListener('click', function(e) {
            if (e.target.tagName === 'A') {
                sessionStorage.setItem('sidebar-scroll', this.scrollTop);
            }
        }, { passive: true });
        var sidebarScrollTop = sessionStorage.getItem('sidebar-scroll');
        sessionStorage.removeItem('sidebar-scroll');
        if (sidebarScrollTop) {
            // preserve sidebar scroll position when navigating via links within sidebar
            this.scrollTop = sidebarScrollTop;
        } else {
            // scroll sidebar to current active section when navigating via "next/previous chapter" buttons
            var activeSection = document.querySelector('#sidebar .active');
            if (activeSection) {
                activeSection.scrollIntoView({ block: 'center' });
            }
        }
        // Toggle buttons
        var sidebarAnchorToggles = document.querySelectorAll('#sidebar a.toggle');
        function toggleSection(ev) {
            ev.currentTarget.parentElement.classList.toggle('expanded');
        }
        Array.from(sidebarAnchorToggles).forEach(function (el) {
            el.addEventListener('click', toggleSection);
        });
    }
}
window.customElements.define("mdbook-sidebar-scrollbox", MDBookSidebarScrollbox);
