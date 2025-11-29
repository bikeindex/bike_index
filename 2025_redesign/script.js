// Testimonials data with images
const testimonials = [
    {
        userName: "Sarah Johnson, Seattle",
        recoveryDate: "03.15.2024",
        text: "I couldn't believe it when I got the call that my bike was found! The Bike Index made it so easy to report and helped connect me with the person who found it.",
        image: "Bike Photo 1"
    },
    {
        userName: "Mike Chen, Portland",
        recoveryDate: "02.28.2024",
        text: "My vintage road bike was stolen from downtown. Thanks to Bike Index's database, a bike shop recognized it and contacted me. Got my bike back in perfect condition!",
        image: "Bike Photo 2"
    },
    {
        userName: "Jessica Rodriguez, San Francisco",
        recoveryDate: "04.02.2024",
        text: "The police found my bike and used Bike Index to track me down. Without this registry, I never would have gotten my commuter bike back. Thank you!",
        image: "Bike Photo 3"
    }
];

let currentTestimonialIndex = 0;
let currentStepIndex = 0;

// Recovery process steps data
const recoverySteps = [
    {
        stepNumber: "STEP 1",
        title: "REGISTER YOUR BIKE",
        text: "It's simple. Submit your name, bike manufacturer, serial number, and component information to enter your bike into the most widely used bike registry on the planet.",
        background: "assets/Step1.gif",
        rotation: 0
    },
    {
        stepNumber: "STEP 2",
        title: "ALERT THE COMMUNITY",
        text: "If your bike goes missing, mark it as lost or stolen to notify the entire Bike Index community and its partners.",
        background: "assets/Step2.gif",
        rotation: 90
    },
    {
        stepNumber: "STEP 3",
        title: "THE COMMUNITY RESPONDS",
        text: "A user or partner encounters your bike, uses Bike Index to identify it, and contacts you.",
        background: "assets/Step3.gif",
        rotation: 180
    },
    {
        stepNumber: "STEP 4",
        title: "YOU GET YOUR BIKE BACK",
        text: "With the help of the Bike Index community and its partners, you have the information necessary to recover your lost or stolen bike at no cost to you. It's what we do.",
        background: "assets/Step4.gif",
        rotation: 270
    }
];

// Scroll-based rider animation and background opacity
function handleScroll() {
    const riderGif = document.querySelector('.rider-gif');
    const heroSection = document.querySelector('.hero-section');
    const heroRect = heroSection.getBoundingClientRect();
    
    // Calculate scroll progress through hero section
    const heroHeight = heroSection.offsetHeight;
    const scrollProgress = Math.max(0, Math.min(1, (window.innerHeight - heroRect.top) / (window.innerHeight + heroHeight)));
    
    // Move bike based on scroll progress
    const maxDistance = window.innerWidth + 400; // Total distance to travel
    const currentPosition = -200 + (scrollProgress * maxDistance);
    
    riderGif.style.transform = `translateY(-50%) translateX(${currentPosition}px)`;
    
    // Calculate background opacity based on text position
    // Full opacity when text is in center area (40-60% of scroll progress)
    // Lower opacity when text is over transparent areas
    let backgroundOpacity;
    if (scrollProgress >= 0.4 && scrollProgress <= 0.6) {
        // Text is in center area - full opacity
        backgroundOpacity = 1.0;
    } else if (scrollProgress < 0.2 || scrollProgress > 0.8) {
        // Text is over transparent areas - lower opacity
        backgroundOpacity = 0.3;
    } else {
        // Transition areas - gradient opacity
        if (scrollProgress < 0.4) {
            backgroundOpacity = 0.3 + (scrollProgress - 0.2) / 0.2 * 0.7;
        } else {
            backgroundOpacity = 1.0 - (scrollProgress - 0.6) / 0.2 * 0.7;
        }
    }
    
    // Apply opacity to background image
    heroSection.style.setProperty('--bg-opacity', backgroundOpacity);
    
    // Toggle white overlay opacity with bike animation
    const whiteOverlayOpacity = scrollProgress > 0.3 ? 0.2 : 0;
    heroSection.style.setProperty('--white-overlay-opacity', whiteOverlayOpacity);
}

// Update testimonial display
function updateTestimonial(index) {
    const testimonial = testimonials[index];
    
    document.getElementById('userName').textContent = testimonial.userName;
    document.getElementById('recoveryDate').textContent = `Bike recovered on ${testimonial.recoveryDate}`;
    document.getElementById('testimonialText').textContent = testimonial.text;
    
    // Update bike image
    const bikePhoto = document.getElementById('bikePhoto');
    bikePhoto.innerHTML = `<div class="placeholder-content">${testimonial.image}</div>`;
}

// Next testimonial
function nextTestimonial() {
    currentTestimonialIndex = (currentTestimonialIndex + 1) % testimonials.length;
    updateTestimonial(currentTestimonialIndex);
}

// Previous testimonial
function prevTestimonial() {
    currentTestimonialIndex = (currentTestimonialIndex - 1 + testimonials.length) % testimonials.length;
    updateTestimonial(currentTestimonialIndex);
}

// Update recovery step display
function updateStep(index) {
    const step = recoverySteps[index];

    // Update text content
    const stepText = document.getElementById('stepText');
    stepText.innerHTML = `
        <h3>
            <span class="step-number">${step.stepNumber}</span>
            <span class="step-title">${step.title}</span>
        </h3>
        <p>${step.text}</p>
    `;

    // Update background image
    document.getElementById('stepBackground').src = step.background;

    // Rotate crank
    document.getElementById('bikeCrank').style.transform = `rotate(${step.rotation}deg)`;

    // Update indicator
    document.getElementById('stepIndicator').textContent = `${index + 1} / 4`;
}

// Next step
function nextStep() {
    currentStepIndex = (currentStepIndex + 1) % recoverySteps.length;
    updateStep(currentStepIndex);
}

// Previous step
function prevStep() {
    currentStepIndex = (currentStepIndex - 1 + recoverySteps.length) % recoverySteps.length;
    updateStep(currentStepIndex);
}

// Bike transition animation
function startBikeTransition() {
    const bikeRegistered = document.getElementById('bikeRegistered');
    const bikeStolen = document.getElementById('bikeStolen');
    
    setInterval(() => {
        // Fade out registered, fade in stolen
        bikeRegistered.style.opacity = '0';
        bikeStolen.style.opacity = '1';
        
        setTimeout(() => {
            // Fade out stolen, fade in registered
            bikeRegistered.style.opacity = '1';
            bikeStolen.style.opacity = '0';
        }, 3000); // Show stolen for 3 seconds
    }, 6000); // Complete cycle every 6 seconds
}

// Generate bike tiles grid
function generateBikeTiles() {
    const grid = document.getElementById('bikeTilesGrid');
    if (!grid) return;

    const bikeImages = [
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

    // Calculate how many tiles we need to fill the screen plus overflow
    const tilesNeeded = Math.ceil((window.innerWidth * 1.2) / 130) * Math.ceil((window.innerHeight * 1.2) / 130);

    // Calculate grid dimensions
    const columns = Math.ceil((window.innerWidth * 1.2) / 130);

    let lastImage = null;
    let lastRowImages = [];

    for (let i = 0; i < tilesNeeded; i++) {
        const tile = document.createElement('div');
        tile.className = 'bike-tile';

        // Get column position to check tile above
        const col = i % columns;
        const imageAbove = lastRowImages[col];

        // Select random image that's different from left neighbor and tile above
        let randomImage;
        let attempts = 0;
        do {
            randomImage = bikeImages[Math.floor(Math.random() * bikeImages.length)];
            attempts++;
        } while ((randomImage === lastImage || randomImage === imageAbove) && attempts < 50);

        tile.style.backgroundImage = `url('${randomImage}')`;

        // Add random slight rotation variation
        const randomRotation = (Math.random() - 0.5) * 10;
        tile.style.transform = `rotate(${5 + randomRotation}deg)`;

        grid.appendChild(tile);

        // Update tracking
        lastImage = randomImage;
        lastRowImages[col] = randomImage;
    }

    // Select a random tile to be the "stolen alert" tile - around central region but not behind shields/text
    const allTiles = grid.querySelectorAll('.bike-tile');
    if (allTiles.length > 0) {
        // Get hero content position to find central area
        const heroContent = document.querySelector('.hero-content');
        const heroRect = heroContent.getBoundingClientRect();

        // Define ring around the hero text (outer radius minus inner exclusion zone)
        const centerX = window.innerWidth / 2;
        const centerY = heroRect.top + (heroRect.height / 2);
        const outerRadiusX = 500; // Outer horizontal radius
        const outerRadiusY = 400; // Outer vertical radius
        const innerRadiusX = 250; // Inner exclusion horizontal radius (where shields/text are)
        const innerRadiusY = 200; // Inner exclusion vertical radius

        const ringTiles = Array.from(allTiles).filter(tile => {
            const rect = tile.getBoundingClientRect();
            const tileCenterX = rect.left + (rect.width / 2);
            const tileCenterY = rect.top + (rect.height / 2);

            const distanceX = Math.abs(tileCenterX - centerX);
            const distanceY = Math.abs(tileCenterY - centerY);

            // Check if tile is in the ring (within outer radius but outside inner radius)
            const inOuterEllipse = distanceX <= outerRadiusX && distanceY <= outerRadiusY;
            const inInnerEllipse = distanceX <= innerRadiusX && distanceY <= innerRadiusY;

            return inOuterEllipse && !inInnerEllipse &&
                   rect.top >= 0 &&
                   rect.bottom <= window.innerHeight;
        });

        // Select from ring tiles only
        if (ringTiles.length > 0) {
            const randomIndex = Math.floor(Math.random() * ringTiles.length);
            const stolenTile = ringTiles[randomIndex];
            stolenTile.classList.add('stolen-alert');

            // Make it clickable to scroll to stolen section
            stolenTile.addEventListener('click', function() {
                const stolenSection = document.querySelector('.stolen-question-section');
                if (stolenSection) {
                    stolenSection.scrollIntoView({ behavior: 'smooth' });
                }
            });
        }
    }
}

// Animate counting up numbers
function animateCount(element, target, duration = 3000) {
    const start = 0;
    const increment = target / (duration / 16); // 60fps
    let current = start;

    const timer = setInterval(() => {
        current += increment;
        if (current >= target) {
            current = target;
            clearInterval(timer);
        }

        // Update the display based on which stat this is
        if (element.textContent.includes('$')) {
            element.textContent = `$${Math.floor(current)}M+`;
        } else if (element.textContent.includes('+')) {
            element.textContent = `${Math.floor(current).toLocaleString()}+`;
        } else {
            element.textContent = Math.floor(current);
        }
    }, 16);
}

// Initialize page
document.addEventListener('DOMContentLoaded', function() {
    // Generate bike tiles
    generateBikeTiles();

    // Set up testimonial navigation
    document.getElementById('nextTestimonial').addEventListener('click', nextTestimonial);
    document.getElementById('prevTestimonial').addEventListener('click', prevTestimonial);

    // Initialize first testimonial
    updateTestimonial(0);

    // Start bike transition animation
    startBikeTransition();

    // Set up step navigation
    document.getElementById('nextStep').addEventListener('click', nextStep);
    document.getElementById('prevStep').addEventListener('click', prevStep);

    // Initialize first step
    updateStep(0);

    // Animate stat numbers on load
    setTimeout(() => {
        document.querySelectorAll('.stat-number[data-target]').forEach(el => {
            const target = parseInt(el.getAttribute('data-target'));
            animateCount(el, target);
        });
    }, 500); // Delay to sync with fade-in animation
});

// Smooth scrolling for internal links (if any are added later)
document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', function (e) {
        e.preventDefault();
        const target = document.querySelector(this.getAttribute('href'));
        if (target) {
            target.scrollIntoView({
                behavior: 'smooth'
            });
        }
    });
});