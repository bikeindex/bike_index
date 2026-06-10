// Resources Page JavaScript

// Initialize bike tiles grid background
document.addEventListener('DOMContentLoaded', function() {
    const bikeTilesGrid = document.getElementById('leBikeTilesGrid');

    if (bikeTilesGrid) {
        // Array of bike tile images
        const bikeTileImages = [
            'assets/BikeTiles/bike-entry_0000_New-group.png',
            'assets/BikeTiles/bike-entry_0001_New-group.png',
            'assets/BikeTiles/bike-entry_0002_New-group.png',
            'assets/BikeTiles/bike-entry_0003_New-group.png',
            'assets/BikeTiles/bike-entry_0004_New-group.png',
            'assets/BikeTiles/bike-entry_0005_New-group.png',
            'assets/BikeTiles/bike-entry_0006_New-group.png',
            'assets/BikeTiles/bike-entry_0007_New-group.png',
            'assets/BikeTiles/bike-entry_0008_New-group.png',
            'assets/BikeTiles/bike-entry_0009_New-group.png',
            'assets/BikeTiles/bike-entry_0010_New-group.png',
            'assets/BikeTiles/bike-entry_0011_New-group.png',
            'assets/BikeTiles/bike-entry_0012_New-group.png',
            'assets/BikeTiles/bike-entry_0013_New-group.png',
            'assets/BikeTiles/bike-entry_0014_New-group.png',
            'assets/BikeTiles/bike-entry_0015_New-group.png',
            'assets/BikeTiles/bike-entry_0016_New-group.png'
        ];

        // Calculate how many tiles we need to fill the screen
        const tilesNeeded = Math.ceil(window.innerWidth / 130) * Math.ceil(window.innerHeight / 130) + 20;

        // Generate tiles
        for (let i = 0; i < tilesNeeded; i++) {
            const tile = document.createElement('div');
            tile.className = 'le-bike-tile';
            const randomImage = bikeTileImages[Math.floor(Math.random() * bikeTileImages.length)];
            tile.style.backgroundImage = `url('${randomImage}')`;
            bikeTilesGrid.appendChild(tile);
        }
    }

    // Smooth scroll for anchor links
    const smoothScrollLinks = document.querySelectorAll('a[href^="#"]');

    smoothScrollLinks.forEach(link => {
        link.addEventListener('click', function(e) {
            const href = this.getAttribute('href');

            // Don't prevent default for links like #login, #signup that might have their own handlers
            if (href === '#' || href.length <= 1) {
                return;
            }

            const target = document.querySelector(href);

            if (target) {
                e.preventDefault();
                target.scrollIntoView({
                    behavior: 'smooth',
                    block: 'start'
                });
            }
        });
    });

    // Add subtle parallax effect to hero background on scroll
    let ticking = false;

    window.addEventListener('scroll', function() {
        if (!ticking) {
            window.requestAnimationFrame(function() {
                const scrolled = window.pageYOffset;
                const heroSection = document.querySelector('.le-hero-section');

                if (heroSection && scrolled < window.innerHeight) {
                    bikeTilesGrid.style.transform = `translateY(${scrolled * 0.3}px)`;
                }

                ticking = false;
            });

            ticking = true;
        }
    });

    // Add entrance animation for resource cards when they come into view
    const observerOptions = {
        threshold: 0.2,
        rootMargin: '0px 0px -50px 0px'
    };

    const observer = new IntersectionObserver(function(entries) {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                entry.target.style.opacity = '1';
                entry.target.style.transform = 'translateY(0)';
            }
        });
    }, observerOptions);

    // Observe resource cards and dev resource items
    const animatedElements = document.querySelectorAll('.resource-card, .dev-resource-item');

    animatedElements.forEach((el, index) => {
        el.style.opacity = '0';
        el.style.transform = 'translateY(30px)';
        el.style.transition = `opacity 0.6s ease ${index * 0.1}s, transform 0.6s ease ${index * 0.1}s`;
        observer.observe(el);
    });
});
