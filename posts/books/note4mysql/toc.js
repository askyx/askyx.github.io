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
        this.innerHTML = '<ol class="chapter"><li class="chapter-item expanded affix "><a href="index.html">MySQL learning notes</a></li><li class="chapter-item expanded "><a href="brainstorm.html"><strong aria-hidden="true">1.</strong> brainstorm</a></li><li class="chapter-item expanded affix "><li class="part-title">basic</li><li class="chapter-item expanded "><a href="before/installation.html"><strong aria-hidden="true">2.</strong> 安装</a></li><li class="chapter-item expanded "><a href="before/commands.html"><strong aria-hidden="true">3.</strong> 基础命令</a></li><li class="chapter-item expanded "><a href="before/debugging.html"><strong aria-hidden="true">4.</strong> 调试技巧</a></li><li><ol class="section"><li class="chapter-item expanded "><a href="before/trace.html"><strong aria-hidden="true">4.1.</strong> trace</a></li><li class="chapter-item expanded "><a href="before/debug.html"><strong aria-hidden="true">4.2.</strong> debug</a></li></ol></li><li class="chapter-item expanded "><a href="before/readbook.html"><strong aria-hidden="true">5.</strong> readbook</a></li><li class="chapter-item expanded "><a href="before/thinking.html"><strong aria-hidden="true">6.</strong> 思考</a></li><li class="chapter-item expanded affix "><li class="part-title">MySQL</li><li class="chapter-item expanded "><a href="mysql/basic/index.html"><strong aria-hidden="true">7.</strong> MySQL基础</a></li><li><ol class="section"><li class="chapter-item expanded "><a href="mysql/basic/parameters.html"><strong aria-hidden="true">7.1.</strong> MySQL参数实现</a></li></ol></li><li class="chapter-item expanded "><a href="internal/optimizer/all.html"><strong aria-hidden="true">8.</strong> MySQL优化器汇总</a></li><li><ol class="section"><li class="chapter-item expanded "><a href="internal/parser/index.html"><strong aria-hidden="true">8.1.</strong> parser</a></li><li class="chapter-item expanded "><a href="internal/binder/index.html"><strong aria-hidden="true">8.2.</strong> binder</a></li><li class="chapter-item expanded "><a href="internal/optimizer/index.html"><strong aria-hidden="true">8.3.</strong> optimizer</a></li><li><ol class="section"><li class="chapter-item expanded "><a href="internal/optimizer/cost.html"><strong aria-hidden="true">8.3.1.</strong> cost</a></li></ol></li><li class="chapter-item expanded "><a href="internal/executor/executor.html"><strong aria-hidden="true">8.4.</strong> executor</a></li><li class="chapter-item expanded "><a href="internal/subquery/index.html"><strong aria-hidden="true">8.5.</strong> subquery</a></li></ol></li><li class="chapter-item expanded "><a href="internal/expression.html"><strong aria-hidden="true">9.</strong> expression</a></li><li class="chapter-item expanded "><a href="internal/storage/index.html"><strong aria-hidden="true">10.</strong> storage</a></li><li><ol class="section"><li class="chapter-item expanded "><a href="internal/storage/performance_schema.html"><strong aria-hidden="true">10.1.</strong> performance_schema</a></li><li class="chapter-item expanded "><a href="internal/storage/innodb.html"><strong aria-hidden="true">10.2.</strong> innodb</a></li></ol></li><li class="chapter-item expanded "><a href="internal/binlog/index.html"><strong aria-hidden="true">11.</strong> binlog</a></li><li class="chapter-item expanded "><a href="internal/extension/index.html"><strong aria-hidden="true">12.</strong> extension</a></li><li class="chapter-item expanded affix "><li class="part-title">workNote</li><li class="chapter-item expanded "><a href="workNote/index.html"><strong aria-hidden="true">13.</strong> workNote</a></li><li class="chapter-item expanded affix "><li class="part-title">Others</li><li class="chapter-item expanded "><a href="faq.html"><strong aria-hidden="true">14.</strong> FAQ</a></li><li class="chapter-item expanded "><a href="changelog.html"><strong aria-hidden="true">15.</strong> Changelog</a></li><li class="chapter-item expanded affix "><li class="spacer"></li><li class="chapter-item expanded affix "><a href="endding.html">The end</a></li></ol>';
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
