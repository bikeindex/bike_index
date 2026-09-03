// Universities Page JavaScript

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

    // Tab functionality
    const tabButtons = document.querySelectorAll('.le-tab-button');
    const tabPanels = document.querySelectorAll('.le-tab-panel');

    tabButtons.forEach(button => {
        button.addEventListener('click', function() {
            const tabName = this.getAttribute('data-tab');

            // Remove active class from all buttons and panels
            tabButtons.forEach(btn => btn.classList.remove('active'));
            tabPanels.forEach(panel => panel.classList.remove('active'));

            // Add active class to clicked button and corresponding panel
            this.classList.add('active');
            document.getElementById('tab-' + tabName).classList.add('active');
        });
    });

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

    // Testimonials carousel functionality
    const testimonials = document.querySelectorAll('.le-testimonial');
    const testimonialPrev = document.getElementById('testimonialPrev');
    const testimonialNext = document.getElementById('testimonialNext');
    const testimonialDotsContainer = document.getElementById('testimonialDots');
    let currentTestimonialIndex = 0;

    // Create dots
    testimonials.forEach((_, index) => {
        const dot = document.createElement('button');
        dot.className = 'le-testimonial-dot';
        if (index === 0) dot.classList.add('active');
        dot.addEventListener('click', () => showTestimonial(index));
        testimonialDotsContainer.appendChild(dot);
    });

    const dots = document.querySelectorAll('.le-testimonial-dot');

    function showTestimonial(index) {
        // Remove active class from all testimonials and dots
        testimonials.forEach(t => t.classList.remove('active'));
        dots.forEach(d => d.classList.remove('active'));

        // Add active class to current testimonial and dot
        testimonials[index].classList.add('active');
        dots[index].classList.add('active');

        currentTestimonialIndex = index;
    }

    testimonialPrev.addEventListener('click', () => {
        currentTestimonialIndex = (currentTestimonialIndex - 1 + testimonials.length) % testimonials.length;
        showTestimonial(currentTestimonialIndex);
    });

    testimonialNext.addEventListener('click', () => {
        currentTestimonialIndex = (currentTestimonialIndex + 1) % testimonials.length;
        showTestimonial(currentTestimonialIndex);
    });

    // Auto-advance testimonials every 8 seconds
    setInterval(() => {
        currentTestimonialIndex = (currentTestimonialIndex + 1) % testimonials.length;
        showTestimonial(currentTestimonialIndex);
    }, 8000);

    // Add entrance animation for stats when they come into view
    const observerOptions = {
        threshold: 0.3,
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

    // Observe feature blocks and tool items
    const animatedElements = document.querySelectorAll('.le-feature-block, .le-tool-item');

    animatedElements.forEach(el => {
        el.style.opacity = '0';
        el.style.transform = 'translateY(30px)';
        el.style.transition = 'opacity 0.6s ease, transform 0.6s ease';
        observer.observe(el);
    });
});
