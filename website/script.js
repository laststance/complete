/**
 * Complete Landing Page - Download Link Management
 * Fetches latest release from GitHub API and updates download buttons
 */

(function() {
    'use strict';

    const GITHUB_API = 'https://api.github.com/repos/laststance/complete/releases/latest';
    const FALLBACK_URL = 'https://github.com/laststance/complete/releases';

    /**
     * Fetches the latest release from GitHub API
     * @returns {Promise<Object>} Release data
     */
    async function fetchLatestRelease() {
        try {
            const response = await fetch(GITHUB_API);

            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }

            return await response.json();
        } catch (error) {
            console.error('Failed to fetch latest release:', error);
            return null;
        }
    }

    /**
     * Finds the .dmg asset from release assets
     * @param {Array} assets - Release assets array
     * @returns {Object|null} DMG asset or null
     */
    function findDmgAsset(assets) {
        if (!Array.isArray(assets)) {
            return null;
        }

        return assets.find(asset =>
            asset.name && asset.name.toLowerCase().endsWith('.dmg')
        );
    }

    /**
     * Updates all download buttons with the DMG download URL
     * @param {string} url - Download URL
     */
    function updateDownloadButtons(url) {
        const buttons = document.querySelectorAll('.download-btn');

        buttons.forEach(button => {
            button.href = url;
            button.setAttribute('download', '');

            // Add subtle animation on update
            button.style.animation = 'none';
            setTimeout(() => {
                button.style.animation = '';
            }, 10);
        });
    }

    /**
     * Updates all version text elements
     * @param {string} version - Version tag (e.g., "v0.1.0")
     */
    function updateVersionText(version) {
        const versionElements = document.querySelectorAll('.version-text');

        versionElements.forEach(element => {
            element.textContent = version;
        });
    }

    /**
     * Sets fallback URL when release fetch fails
     */
    function setFallbackUrl() {
        const buttons = document.querySelectorAll('.download-btn');

        buttons.forEach(button => {
            button.href = FALLBACK_URL;
            button.removeAttribute('download');
        });

        console.info('Using fallback URL:', FALLBACK_URL);
    }

    /**
     * Main initialization function
     */
    async function init() {
        const release = await fetchLatestRelease();

        if (!release) {
            setFallbackUrl();
            return;
        }

        const dmgAsset = findDmgAsset(release.assets);

        if (dmgAsset && dmgAsset.browser_download_url) {
            updateDownloadButtons(dmgAsset.browser_download_url);
            console.info('Download URL updated:', dmgAsset.browser_download_url);
        } else {
            setFallbackUrl();
            console.warn('No .dmg asset found in release');
        }

        if (release.tag_name) {
            updateVersionText(release.tag_name);
            console.info('Version updated:', release.tag_name);
        }
    }

    // Initialize when DOM is ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }

    // Add smooth scroll behavior for anchor links
    document.addEventListener('click', (e) => {
        const target = e.target.closest('a[href^="#"]');

        if (!target) return;

        const href = target.getAttribute('href');
        if (href === '#' || href === '#download') {
            e.preventDefault();
            const section = document.getElementById('download');

            if (section) {
                section.scrollIntoView({
                    behavior: 'smooth',
                    block: 'start'
                });
            }
        }
    });

    // Add keyboard navigation enhancement
    document.addEventListener('keydown', (e) => {
        // Escape key to scroll to top
        if (e.key === 'Escape') {
            window.scrollTo({
                top: 0,
                behavior: 'smooth'
            });
        }
    });

    // Add scroll-triggered animations for sections
    const observerOptions = {
        threshold: 0.1,
        rootMargin: '0px 0px -100px 0px'
    };

    const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                entry.target.style.opacity = '1';
                entry.target.style.transform = 'translateY(0)';
            }
        });
    }, observerOptions);

    // Observe sections for scroll animations
    const sections = document.querySelectorAll('section');
    sections.forEach(section => {
        section.style.opacity = '0';
        section.style.transform = 'translateY(30px)';
        section.style.transition = 'opacity 0.6s ease, transform 0.6s cubic-bezier(0.34, 1.56, 0.64, 1)';
        observer.observe(section);
    });

    // Performance monitoring (development only)
    if (window.performance && window.performance.timing) {
        window.addEventListener('load', () => {
            const timing = performance.timing;
            const loadTime = timing.loadEventEnd - timing.navigationStart;
            console.info(`Page load time: ${loadTime}ms`);
        });
    }
})();
