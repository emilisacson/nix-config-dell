#!/usr/bin/env node
/**
 * Automated Citrix Workspace Downloader
 * * This script uses puppeteer to automate downloading the latest Citrix Workspace RPM
 * by handling the EULA acceptance popup and waiting for download completion.
 * * Requirements:
 * - Node.js (v14+)
 * - npm packages: puppeteer-core, minimist
 * * How to use:
 * 1. Install dependencies: npm install puppeteer-core minimist
 * 2. Run: node auto-download-citrix.js --download-dir=/path/to/downloads
 */

const puppeteer = require('puppeteer-core');
const fs = require('fs');
const path = require('path');
const minimist = require('minimist');
const { execSync } = require('child_process');

// Parse command line arguments
const args = minimist(process.argv.slice(2), {
    default: {
        'download-dir': path.join(process.env.HOME, 'Downloads'),
        'chrome-path': null, // Will be auto-detected
        'firefox-path': null, // Will be auto-detected
        'browser': null, // Auto-detect browser
        'debug': false,
        'headless': true, // New parameter: control headless mode separately
        'version': null,
        'timeout': 120, // 2 minutes default timeout
        'url': 'https://www.citrix.com/downloads/workspace-app/linux/workspace-app-for-linux-latest.html' // Default URL
    },
    boolean: ['debug', 'headless']
});

// Function to check if a file exists
function fileExists(filePath) {
    try {
        return fs.existsSync(filePath);
    } catch (e) {
        return false;
    }
}

// Function to find browser executable
async function findBrowser() {
    // If user specified a browser, prioritize that choice
    if (args.browser) {
        if (args.browser.toLowerCase() === 'firefox') {
            return await findFirefoxPath();
        } else {
            return await findChromePath();
        }
    }

    // If user specified a direct path, use that
    if (args['chrome-path'] && fileExists(args['chrome-path'])) {
        console.log(`Using specified Chrome path: ${args['chrome-path']}`);
        return { type: 'chrome', path: args['chrome-path'] };
    }

    if (args['firefox-path'] && fileExists(args['firefox-path'])) {
        console.log(`Using specified Firefox path: ${args['firefox-path']}`);
        return { type: 'firefox', path: args['firefox-path'] };
    }

    // First try to detect Chrome/Chromium (prioritize over Firefox)
    try {
        const chromeInfo = await findChromePath();
        if (chromeInfo) {
            console.log("Using detected Chrome/Chromium browser");
            return chromeInfo;
        }
    } catch (e) {
        console.log("Chrome/Chromium not found, trying Firefox...");
    }

    // Try Firefox as fallback
    try {
        const firefoxInfo = await findFirefoxPath();
        if (firefoxInfo) {
            console.log("Using Firefox as fallback");
            return firefoxInfo;
        }
    } catch (e) {
        console.log("Firefox not found either.");
    }

    throw new Error('Could not find any compatible browser. Please specify --firefox-path or --chrome-path');
}

// Function to find Firefox on different platforms
async function findFirefoxPath() {
    const firefoxPaths = [
        args['firefox-path'],
        '/usr/bin/firefox',
        '/usr/lib/firefox/firefox',
        '/usr/lib64/firefox/firefox',
        '/usr/local/bin/firefox',
        '/Applications/Firefox.app/Contents/MacOS/firefox', // For macOS
        '/snap/bin/firefox',
        // Add Nix-specific path
        '/run/current-system/sw/bin/firefox'
    ];

    for (const browserPath of firefoxPaths) {
        if (browserPath && fileExists(browserPath)) {
            console.log(`Found Firefox at ${browserPath}`);
            return { type: 'firefox', path: browserPath };
        }
    }

    return null;
}

// Function to find Chrome/Chromium on different platforms
async function findChromePath() {
    const chromePaths = [
        args['chrome-path'],
        '/usr/bin/google-chrome',
        '/usr/bin/google-chrome-stable',
        '/usr/bin/chromium',
        '/usr/bin/chromium-browser',
        '/usr/bin/brave-browser', // Brave is Chromium-based
        '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', // For macOS
        '/Applications/Brave Browser.app/Contents/MacOS/Brave Browser',
        '/snap/bin/chromium',
        // Add Nix-specific paths
        '/run/current-system/sw/bin/google-chrome-stable',
        '/run/current-system/sw/bin/chromium',
        '/run/current-system/sw/bin/brave',
        // Add Nix home profile path for brave
        `${process.env.HOME}/.nix-profile/bin/brave`
    ];

    for (const browserPath of chromePaths) {
        if (browserPath && fileExists(browserPath)) {
            console.log(`Found Chrome/Chromium at ${browserPath}`);
            return { type: 'chrome', path: browserPath };
        }
    }

    return null;
}

// Monitor download directory for new files
function monitorDownloads(downloadDir, initialFiles = []) {
    return new Promise(resolve => {
        let checkInterval = null;
        let lastSizeCheckTime = Date.now();
        let lastFileSize = 0;
        let lastFileName = null;
        let noProgressCount = 0;
        let totalSize = 0; // Expected file size (if known)
        let downloadReported = false; // Track if we've already reported download completion
        let downloadStartReportedByMonitor = false;
        let completedFilesFound = false; // New flag to track if we've found completed files
        let pendingCompletionDisplay = false; // Flag to indicate we're waiting to show 100% before completion
        let pendingCompletionFiles = []; // Store completed files while waiting to show 100%

        const reportedFiles = new Set();

        if (!initialFiles || !initialFiles.length) {
            initialFiles = fs.readdirSync(downloadDir);
        }
        const initialFileSet = new Set(initialFiles);

        const progressBarLength = 40;
        let progressLine = '';

        const drawProgressBar = (current, total) => {
            if (progressLine) {
                process.stdout.clearLine(0);
                process.stdout.cursorTo(0);
            }
            const percent = total ? Math.min(100, Math.round((current / total) * 100)) : 0;
            const filledLength = total ? Math.round((current / total) * progressBarLength) : 0;
            const filled = '█'.repeat(filledLength);
            const empty = '░'.repeat(progressBarLength - filledLength);
            const currentMB = (current / (1024 * 1024)).toFixed(1);
            const totalMB = total ? (total / (1024 * 1024)).toFixed(1) : '??';
            progressLine = `Downloading: [${filled}${empty}] ${currentMB}MB / ${totalMB}MB (${percent}%)`;
            process.stdout.write(progressLine);
        };

        // Show 100% progress bar before completion message
        const showFullProgress = () => {
            if (totalSize > 0 && progressLine) {
                process.stdout.clearLine(0);
                process.stdout.cursorTo(0);
                const filled = '█'.repeat(progressBarLength);
                const currentMB = (totalSize / (1024 * 1024)).toFixed(1);
                const totalMB = (totalSize / (1024 * 1024)).toFixed(1);
                progressLine = `Downloading: [${filled}] ${totalMB}MB / ${totalMB}MB (100%)`;
                process.stdout.write(progressLine);
                return true;
            }
            return false;
        };

        // Function to display the completed message after ensuring 100% progress is shown
        const displayCompletionMessage = (fileDetails) => {
            // Show 100% progress first
            showFullProgress();

            // Add a small delay to let the user see the 100% before showing completion
            setTimeout(() => {
                // Ensure progress bar is cleared before printing final message
                if (process.stdout.isTTY && progressLine) {
                    process.stdout.clearLine(0);
                    process.stdout.cursorTo(0);
                    progressLine = ''; // Reset progressLine
                } else if (progressLine) {
                    console.log(); // Add a newline if not TTY but progressLine was active
                    progressLine = '';
                }

                console.log(`\n============================================`);
                console.log(`✓ DOWNLOAD COMPLETED SUCCESSFULLY ✓`);
                console.log(`Files:`);
                fileDetails.forEach(file => {
                    console.log(`  • ${file.name} (${Math.round(file.size / 1024)} KB)`);
                });
                console.log(`\nDownload location: ${downloadDir}`);
                console.log('============================================');
                downloadReported = true;
                clearInterval(checkInterval);
                resolve({ completed: true, files: fileDetails, inProgress: false });
            }, 500); // Small delay to ensure user sees 100%
        };

        const checkForNewFiles = () => {
            try {
                const currentTime = Date.now();
                const currentFiles = fs.readdirSync(downloadDir);
                const newFiles = currentFiles.filter(file => !initialFileSet.has(file));

                // Check for completed RPM files
                const completedFiles = newFiles.filter(file =>
                    file.toLowerCase().endsWith('.rpm') && (
                        file.toLowerCase().includes('citrix') ||
                        file.toLowerCase().includes('ica') ||
                        file.toLowerCase().includes('workspace') ||
                        file.toLowerCase().includes('ctx')
                    )
                );

                // If we found completed files and haven't reported download yet
                if (completedFiles.length > 0 && !downloadReported) {
                    // Mark that we've found completed files
                    completedFilesFound = true;

                    const fileDetails = completedFiles
                        .filter(file => !reportedFiles.has(file))
                        .map(file => {
                            const filePath = path.join(downloadDir, file);
                            try {
                                const stats = fs.statSync(filePath);
                                reportedFiles.add(file);
                                return { name: file, path: filePath, size: stats.size };
                            } catch (e) {
                                return { name: file, path: filePath, size: 0 };
                            }
                        });

                    if (fileDetails.length > 0) {
                        // Store file details for later use
                        pendingCompletionFiles = fileDetails;

                        // If we're still showing a download in progress or haven't shown 100% yet
                        if (progressLine && !pendingCompletionDisplay) {
                            // Set the flag to display completion after showing 100%
                            pendingCompletionDisplay = true;

                            // Update total size if we have a better estimate now
                            if (fileDetails[0].size > totalSize) {
                                totalSize = fileDetails[0].size;
                            }

                            // Show 100% and then the completion message
                            displayCompletionMessage(fileDetails);
                            return;
                        } else if (!progressLine) {
                            // If no progress bar is active, show completion directly
                            displayCompletionMessage(fileDetails);
                            return;
                        }
                    }
                }

                // Handle in-progress downloads (partial files)
                const partialFiles = newFiles.filter(file =>
                    file.endsWith('.crdownload') ||
                    file.endsWith('.part') ||
                    file.endsWith('.download') ||
                    file.endsWith('.incomplete')
                );

                // If we have pending completion but no more partial files, show 100% and complete
                if (pendingCompletionDisplay && partialFiles.length === 0 && pendingCompletionFiles.length > 0) {
                    displayCompletionMessage(pendingCompletionFiles);
                    return;
                }

                if (partialFiles.length > 0) {
                    const partialFile = partialFiles[0];
                    const filePath = path.join(downloadDir, partialFile);
                    try {
                        const stats = fs.statSync(filePath);
                        const currentSize = stats.size;

                        if (lastFileName !== partialFile || !downloadStartReportedByMonitor) {
                            if (progressLine) {
                                console.log();
                                progressLine = '';
                            }
                            if (!downloadStartReportedByMonitor) {
                                console.log(`Download started: ${partialFile}`);
                                downloadStartReportedByMonitor = true;
                            }
                            if (partialFile.includes('ICAClient') && (partialFile.includes('rhel') || partialFile.includes('x86_64'))) {
                                totalSize = 450 * 1024 * 1024;
                            }
                            lastFileName = partialFile;
                            lastFileSize = currentSize;
                            lastSizeCheckTime = currentTime;
                            noProgressCount = 0;
                            // Initial draw of progress bar when download starts
                            drawProgressBar(currentSize, totalSize);
                        }

                        // This check is slightly redundant due to setInterval, but harmless.
                        // More importantly, it groups progress update logic.
                        if (currentTime - lastSizeCheckTime >= 450) { // Check slightly less than interval to ensure it fires
                            if (currentSize > lastFileSize) {
                                drawProgressBar(currentSize, totalSize);
                                lastFileSize = currentSize;
                                noProgressCount = 0;

                                // If download is very close to completion and we found completed files,
                                // prepare to show the completion message
                                if (completedFilesFound && totalSize > 0 && currentSize >= totalSize * 0.98) {
                                    pendingCompletionDisplay = true;
                                }
                            } else if (currentSize === lastFileSize && currentSize > 0) { // Still in progress, but no size change
                                noProgressCount++;
                                if (noProgressCount % 20 === 0) { // Log no progress every 10 seconds
                                    if (progressLine) {
                                        console.log();
                                        progressLine = '';
                                    }
                                    console.log(`[DOWNLOAD] No progress detected for ${noProgressCount / 2} seconds on ${partialFile} (size: ${currentSize} bytes)`);
                                    // Redraw progress bar after the "no progress" message
                                    drawProgressBar(currentSize, totalSize);
                                }
                            }
                            lastSizeCheckTime = currentTime; // Always update last check time
                        }

                        if (noProgressCount >= 240) { // 2 minutes of no progress
                            if (progressLine) {
                                console.log();
                                progressLine = '';
                            }
                            console.log('[DOWNLOAD] No progress for 2 minutes, aborting');
                            clearInterval(checkInterval);
                            resolve({ completed: false, inProgress: false, message: 'Download stalled - no progress for 2 minutes' });
                            return;
                        }

                        // If the partial file is very close to completion and we have detected completed files
                        if (completedFilesFound && totalSize > 0 && currentSize >= totalSize * 0.99) {
                            // Mark that we need to show 100% before completion
                            pendingCompletionDisplay = true;
                        }

                        return { completed: false, inProgress: true, partialFile: partialFile, fileSize: currentSize };
                    } catch (e) {
                        if (args.debug) console.log(`Error checking partial file: ${e.message}`);
                    }
                }

                // If we found completed files but there are no more partial files, show completion
                if (completedFilesFound && pendingCompletionFiles.length > 0 && !downloadReported) {
                    displayCompletionMessage(pendingCompletionFiles);
                }

                return null;
            } catch (error) {
                console.error(`Error monitoring downloads: ${error.message}`);
                return null;
            }
        };

        const initialCheckResult = checkForNewFiles();
        if (initialCheckResult && initialCheckResult.completed) {
            return;
        }
        checkInterval = setInterval(checkForNewFiles, 500);
    });
}

// Extract direct download URLs from HTML content
function extractDownloadUrlsFromHtml(htmlContent) {
    const urlRegex = /(?:https?:|\/)\/[^"']+\.rpm(\?[^"']+)?/g;
    const matches = [...htmlContent.matchAll(urlRegex)];
    return matches.map(match => {
        const url = match[0];
        if (url.startsWith('//')) {
            return 'https:' + url;
        }
        return url;
    });
}

// Manual download function - open browser directly to the Citrix page
async function openManualDownload(browser) {
    try {
        console.log('Falling back to manual download method...');
        const citrixUrl = args.url || 'https://www.citrix.com/downloads/workspace-app/linux/workspace-app-for-linux-latest.html';
        const downloadUrl = citrixUrl.startsWith('http') ? citrixUrl : `https://www.citrix.com/downloads/workspace-app/linux/workspace-app-for-linux-latest.html`;
        let cmd;
        if (browser.type === 'firefox') {
            cmd = `"${browser.path}" "${downloadUrl}"`;
        } else {
            cmd = `"${browser.path}" "${downloadUrl}"`;
        }
        console.log(`Opening browser manually: ${cmd}`);
        execSync(cmd, { stdio: 'inherit' });
        console.log('Browser opened to Citrix download page. Please complete the download manually.');
        return { success: true, manual: true };
    } catch (error) {
        console.error('Error opening browser manually:', error.message);
        return { success: false, error: error.message };
    }
}

// Helper function for waiting
async function safeWait(page, timeout) {
    if (typeof page.waitForTimeout === 'function') {
        await page.waitForTimeout(timeout);
    } else if (typeof page.waitFor === 'function') {
        await page.waitFor(timeout);
    } else {
        await new Promise(resolve => setTimeout(resolve, timeout));
    }
}

// Extract direct download URLs
async function getDirectDownloadUrls(page) {
    try {
        const pageContent = await page.content();
        const extractedUrls = extractDownloadUrlsFromHtml(pageContent);
        if (extractedUrls && extractedUrls.length > 0) return extractedUrls;

        const extractResult = await page.evaluate(() => {
            if (window.CTX_Download_Component && window.CTX_Download_Component.props) {
                const directUrls = [];
                window.CTX_Download_Component.props.forEach(prop => {
                    for (const key in prop) {
                        if (prop[key] && prop[key].swFilePath) {
                            const url = prop[key].swFilePath;
                            if (url && url.includes('.rpm')) directUrls.push(url);
                        }
                    }
                });
                return directUrls;
            }
            return [];
        });
        if (extractResult && extractResult.length > 0) return extractResult;

        const htmlPath = path.join(__dirname, 'citrix-rpm-html-elements.html');
        if (fs.existsSync(htmlPath)) {
            const htmlContent = fs.readFileSync(htmlPath, 'utf8');
            return extractDownloadUrlsFromHtml(htmlContent);
        }
        return [];
    } catch (e) {
        console.log(`Error extracting direct URLs: ${e.message}`);
        return [];
    }
}

// Force click all download links
async function forceClickAllDownloadLinks(page) {
    return await page.evaluate(() => {
        const clickedElements = [];
        const downloadLinkTexts = ['download file', 'download', 'download now', 'start download'];
        document.querySelectorAll('a, button, input[type="button"], input[type="submit"]').forEach(el => {
            const text = el.innerText ? el.innerText.toLowerCase() : '';
            if (downloadLinkTexts.some(keyword => text.includes(keyword)) ||
                (el.getAttribute('href') && el.getAttribute('href').includes('download')) ||
                (el.getAttribute('rel') && el.getAttribute('rel').includes('.rpm'))) {
                try {
                    const rect = el.getBoundingClientRect();
                    if (rect.height > 0 && rect.width > 0) {
                        el.click();
                        clickedElements.push({ tag: el.tagName, text: text, href: el.getAttribute('href') || '', id: el.id || '', success: true });
                    }
                } catch (e) { /* Ignore click errors */ }
            }
        });
        document.querySelectorAll('.ctx-dl-link').forEach(el => {
            try {
                el.click();
                clickedElements.push({ tag: el.tagName, text: el.innerText, class: 'ctx-dl-link', success: true });
            } catch (e) { /* Ignore click errors */ }
        });
        const ctxScripts = Array.from(document.querySelectorAll('script'));
        for (const script of ctxScripts) {
            if (script.innerText && script.innerText.includes('window.CTX_Download_Component')) {
                try {
                    const regex = /swFilePath: "([^"]+)"/g;
                    let match; const urls = [];
                    while ((match = regex.exec(script.innerText)) !== null) {
                        if (match[1] && match[1].includes('.rpm')) urls.push(match[1]);
                    }
                    return { clickedElements, directUrls: urls };
                } catch (e) { /* Ignore parsing errors */ }
            }
        }
        return { clickedElements, directUrls: [] };
    });
}

// Download with direct URLs
async function downloadWithDirectUrls(page, directUrls, downloadDir) {
    if (!directUrls || directUrls.length === 0) {
        console.log('No direct download URLs available');
        return false;
    }
    const mainRpmUrl = directUrls.find(url => url.includes('ICAClient') && url.includes('.rpm'));
    if (!mainRpmUrl) {
        console.log('Could not find main ICAClient RPM URL');
        return false;
    }
    const fullUrl = mainRpmUrl.startsWith('http') ? mainRpmUrl : `https:${mainRpmUrl}`;
    console.log(`Attempting direct download using URL: ${fullUrl}`);
    console.log(`Download will be saved to: ${downloadDir}`);
    const initialFiles = fs.readdirSync(downloadDir); // For local check, monitorDownloads handles global

    try {
        try {
            await page.goto(fullUrl, { waitUntil: 'networkidle2', timeout: 10000 });
        } catch (e) {
            if (e.message.includes('net::ERR_ABORTED') || e.message.includes('net::ERR_INVALID_RESPONSE') || e.message.includes('Navigation timeout')) {
                console.log(`Navigation was interrupted - this may indicate download started: ${e.message}`);
            } else {
                if (args.debug) console.log(`Navigation error (potentially benign): ${e.message}`);
            }
        }
        await safeWait(page, 5000); // Allow time for download to begin

        // Check for new files locally as a quick confirmation
        const currentFiles = fs.readdirSync(downloadDir);
        const newFiles = currentFiles.filter(file => !initialFiles.includes(file));
        const downloadingFiles = newFiles.filter(file => file.endsWith('.crdownload') || file.endsWith('.part'));
        if (downloadingFiles.length > 0) return true;

        const citrixFiles = newFiles.filter(file => file.toLowerCase().endsWith('.rpm') && (file.toLowerCase().includes('citrix') || file.toLowerCase().includes('ica')));
        if (citrixFiles.length > 0) return true;

        console.log('No immediate download indicator found after direct URL attempt, main monitor will continue.');
        return true; // Assume attempt was made, let main monitor decide
    } catch (e) {
        console.log(`Error initiating download via direct URL: ${e.message}`);
        return false;
    }
}

// Main function
async function downloadCitrix() {
    console.log('Citrix Workspace Automated Downloader');
    console.log('=====================================');
    const absoluteDownloadPath = path.resolve(args['download-dir']);
    console.log(`Download directory: ${absoluteDownloadPath}`);
    console.log(`Debug mode: ${args.debug ? 'enabled' : 'disabled'}`);
    console.log(`Headless mode: ${args.headless ? 'enabled' : 'disabled'}`);

    if (!fs.existsSync(args['download-dir'])) {
        fs.mkdirSync(args['download-dir'], { recursive: true });
    }
    const initialFiles = fs.readdirSync(args['download-dir']);
    const browserInfo = await findBrowser();
    console.log(`Using browser: ${browserInfo.type} at ${browserInfo.path}`);

    const launchOptions = {
        executablePath: browserInfo.path,
        headless: args.headless,
        args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage', '--disable-accelerated-2d-canvas', '--disable-gpu', '--window-size=1280,800'],
        defaultViewport: { width: 1280, height: 800 }
    };
    if (browserInfo.type === 'firefox') {
        launchOptions.product = 'firefox';
        launchOptions.timeout = 60000;
        launchOptions.args.push('--remote-debugging-port=9222');
    }

    console.log('Launching browser...');
    let puppeteerBrowser = null;
    let downloadResultGlobal = null; // To store result from monitor promise for finally block

    try {
        puppeteerBrowser = await puppeteer.launch(launchOptions);
        let downloadDetectedByMainLogic = false;

        try {
            const page = await puppeteerBrowser.newPage();
            if (args.debug) {
                page.on('console', msg => console.log('PAGE LOG:', msg.text()));
                page.on('request', req => console.log(`REQUEST: ${req.url()}`));
                page.on('response', res => console.log(`RESPONSE: ${res.url()} - ${res.status()}`));
            }

            if (browserInfo.type === 'chrome') {
                try {
                    const client = await page.target().createCDPSession();
                    await client.send('Page.setDownloadBehavior', { behavior: 'allow', downloadPath: args['download-dir'] });
                    client.on('Browser.downloadWillBegin', (event) => { if (args.debug) console.log('[BROWSER EVENT] DownloadWillBegin detected'); });
                    client.on('Browser.downloadProgress', (event) => { if (event.state === 'completed' && args.debug) console.log('[BROWSER EVENT] DownloadProgress: completed'); });
                } catch (e) {
                    console.log(`Warning: Failed to set download path: ${e.message}. Downloads may go to default location.`);
                }
            }

            const downloadMonitorPromise = monitorDownloads(args['download-dir'], initialFiles);
            const citrixUrl = (args.url && args.url.startsWith('http')) ? args.url : 'https://www.citrix.com/downloads/workspace-app/linux/workspace-app-for-linux-latest.html';
            console.log(`\n--- Navigating to Citrix download page ---\n${citrixUrl}`);

            try {
                await page.goto(citrixUrl, { waitUntil: 'networkidle2', timeout: args.timeout * 1000 });
            } catch (e) {
                if (e.message.includes('net::ERR_ABORTED') || e.message.includes('Navigation timeout') || e.message.includes('net::ERR_INVALID_RESPONSE')) {
                    console.log(`Initial page navigation interrupted (may indicate download or page issue): ${e.message}`);
                } else {
                    console.error(`Failed to load page: ${e.message}`);
                    if (!args.debug) await page.screenshot({ path: path.join(args['download-dir'], 'citrix-error.png'), fullPage: true });
                }
                if (args.debug) console.log('Attempting to continue despite navigation issue...');
            }

            try {
                const cookieSelector = 'button[id="onetrust-accept-btn-handler"]';
                await page.waitForSelector(cookieSelector, { visible: true, timeout: 5000 });
                const cookieButton = await page.$(cookieSelector);
                if (cookieButton) {
                    console.log('Accepting cookies...');
                    await cookieButton.click();
                    await safeWait(page, 2000);
                }
            } catch (e) {
                if (args.debug) console.log('No cookie banner found or unable to click it within timeout:', e.message);
            }

            const checkDownloadStatus = async () => {
                const currentFiles = fs.readdirSync(args['download-dir']);
                const partialFiles = currentFiles.filter(file => !initialFiles.includes(file) && (file.endsWith('.crdownload') || file.endsWith('.part')));
                if (partialFiles.length > 0) return true;
                const citrixFiles = currentFiles.filter(file => !initialFiles.includes(file) && file.toLowerCase().endsWith('.rpm') && (file.toLowerCase().includes('citrix') || file.toLowerCase().includes('ica')));
                if (citrixFiles.length > 0) return true;
                return false;
            };

            const attemptDownload = async (methodName, downloadFn) => {
                if (await checkDownloadStatus()) {
                    if (args.debug) console.log(`Download already detected/progressing, skipping ${methodName}`);
                    downloadDetectedByMainLogic = true;
                    return true;
                }
                console.log(`\n--- Attempting download via ${methodName} ---`);
                try {
                    await downloadFn();
                    await safeWait(page, 5000);
                    if (await checkDownloadStatus()) {
                        downloadDetectedByMainLogic = true;
                        return true;
                    }
                    if (args.debug) console.log(`${methodName} did not immediately result in a detected download.`);
                    return false;
                } catch (e) {
                    console.log(`${methodName} failed: ${e.message}`);
                    if (args.debug) console.error(e);
                    return false;
                }
            };

            await attemptDownload('direct download URLs', async () => {
                const directUrls = await getDirectDownloadUrls(page);
                if (directUrls && directUrls.length > 0) {
                    console.log(`Found ${directUrls.length} direct download URLs`);
                    await downloadWithDirectUrls(page, directUrls, args['download-dir']);
                } else {
                    throw new Error('No direct URLs found from getDirectDownloadUrls');
                }
            });

            if (!await checkDownloadStatus()) {
                await attemptDownload('UI interaction', async () => {
                    console.log('Looking for RPM download links via UI...');
                    try {
                        await page.evaluate(() => {
                            const headers = Array.from(document.querySelectorAll('h3, h2, button, div[role="button"]'));
                            const rpmHeader = headers.find(h => h.innerText && (h.innerText.toLowerCase().includes('rpm package') || h.innerText.toLowerCase().includes('linux packages')));
                            if (rpmHeader) { console.log('Clicking RPM section header:', rpmHeader.innerText); rpmHeader.click(); return true; }
                            return false;
                        });
                        await safeWait(page, 3000);
                    } catch (uiError) { if (args.debug) console.log('Could not click RPM section header:', uiError.message); }

                    const downloadLinks = await page.evaluate(() => { /* ... (UI evaluation logic as before, shortened for brevity) ... */
                        const links = Array.from(document.querySelectorAll('a[href*=".rpm"], a[data-download*=".rpm"]'));
                        return links.filter(link => { const text = (link.innerText || link.textContent || '').toLowerCase(); const href = (link.getAttribute('href') || '').toLowerCase(); const parent = link.closest('div'); const surroundingText = parent ? (parent.innerText || parent.textContent || '').toLowerCase() : ''; return ((text.includes('download') || href.includes('download') || text.includes('.rpm') || href.includes('.rpm')) && (surroundingText.includes('rpm') || surroundingText.includes('red hat') || surroundingText.includes('rhel') || surroundingText.includes('linux') || text.includes('icaclient') || href.includes('icaclient'))); }).map(link => ({ text: (link.innerText || link.textContent || '').trim(), href: link.getAttribute('href') || '', id: link.id || '', parentText: (link.closest('div') ? (link.closest('div').innerText || link.closest('div').textContent || '') : '').trim() }));
                    });
                    if (downloadLinks.length === 0) throw new Error('No suitable RPM download links found via UI evaluation.');
                    console.log(`Found ${downloadLinks.length} potential UI download links.`);
                    if (args.debug) console.log(downloadLinks);
                    const mainPackageLinks = downloadLinks.filter(link => (link.href && link.href.toLowerCase().includes('icaclient') && link.href.toLowerCase().includes('rhel')) || (link.text.toLowerCase().includes('icaclient') && link.text.toLowerCase().includes('rhel')) || (link.parentText.toLowerCase().includes('full package') && link.parentText.toLowerCase().includes('icaclient')));
                    let targetLink = mainPackageLinks.length > 0 ? mainPackageLinks[0] : (downloadLinks.length > 0 ? downloadLinks[0] : null);
                    if (!targetLink) throw new Error('No targetable download link found after filtering.');
                    console.log(`Clicking link: "${targetLink.text}" with href: ${targetLink.href}`);
                    await page.evaluate((ld) => { /* ... (click logic as before, shortened for brevity) ... */
                        let cl = false; if (ld.id) { const el = document.getElementById(ld.id); if (el && typeof el.click === 'function') { el.click(); cl = true; } } if (!cl) { const allLn = Array.from(document.querySelectorAll('a')); for (const ln of allLn) { if (ln.getAttribute('href') === ld.href || (ln.innerText || ln.textContent || '').trim() === ld.text) { if (typeof ln.click === 'function') { ln.click(); cl = true; break; } } } } return cl;
                    }, targetLink);
                });
            }

            if (!await checkDownloadStatus()) {
                await attemptDownload('license acceptance', async () => { /* ... (license acceptance logic as before, shortened for brevity) ... */
                    await safeWait(page, 3000); const isLic = await page.evaluate(() => { const txt = (document.body.innerText || document.body.textContent || '').toLowerCase(); return (txt.includes('license agreement') || txt.includes('eula')); }); if (!isLic) throw new Error('No license agreement page detected.'); console.log('License agreement detected, attempting to accept...'); const licAcc = await page.evaluate(() => { let acc = false; document.querySelectorAll('input[type="checkbox"]').forEach(cb => { if (!cb.checked) cb.click(); }); const btns = Array.from(document.querySelectorAll('button, input[type="button"], input[type="submit"], a[role="button"]')); for (const btn of btns) { const txt = (btn.innerText || btn.value || btn.textContent || '').toLowerCase(); if (txt.includes('accept') || txt.includes('agree')) { btn.click(); acc = true; break; } } return acc; }); if (!licAcc) throw new Error('Could not accept license.'); console.log('License agreement accepted/clicked.');
                });
            }

            if (!await checkDownloadStatus()) {
                await attemptDownload('force click all download elements', async () => { /* ... (force click logic as before, shortened for brevity) ... */
                    const clickRes = await forceClickAllDownloadLinks(page); console.log(`Force click: Clicked ${clickRes.clickedElements.length} elements.`); if (clickRes.directUrls && clickRes.directUrls.length > 0) { console.log(`Force click: Found ${clickRes.directUrls.length} direct URLs, attempting.`); await downloadWithDirectUrls(page, clickRes.directUrls, args['download-dir']); } else if (clickRes.clickedElements.length === 0) { throw new Error("Force click found no elements/URLs."); }
                });
            }

            // MODIFICATION: Removed the "--- Awaiting download monitor completion ---" log line.
            // console.log('\n--- Awaiting download monitor completion ---'); 
            downloadResultGlobal = await downloadMonitorPromise;

            if (downloadResultGlobal.completed && downloadResultGlobal.files && downloadResultGlobal.files.length > 0) {
                downloadDetectedByMainLogic = true; // Ensure this is set if monitor completes successfully
                console.log("Download process finished. Monitor reported completion.");
            } else if (downloadResultGlobal.inProgress) {
                console.log('\n============================================');
                console.log('⟳ DOWNLOAD STILL IN PROGRESS (UNEXPECTED MONITOR RESOLVE) ⟳');
                if (downloadResultGlobal.partialFile) console.log(`  • Partial file: ${downloadResultGlobal.partialFile}`);
                console.log('  • Please check download status manually.');
                console.log('============================================\n');
                downloadDetectedByMainLogic = true;
            } else if (downloadResultGlobal.message && downloadResultGlobal.message.includes('stalled')) {
                console.log('\n============================================');
                console.log('✗ DOWNLOAD STALLED ✗');
                console.log(`  • Reason: ${downloadResultGlobal.message}`);
                console.log(`  • Download location: ${absoluteDownloadPath}`);
                console.log('============================================\n');
            } else if (!downloadDetectedByMainLogic && !await checkDownloadStatus()) {
                console.log('\n============================================');
                console.log('✗ NO DOWNLOAD DETECTED OR COMPLETED ✗');
                console.log('  • All attempts failed or monitor timed out without success.');
                console.log(`  • Download location: ${absoluteDownloadPath}`);
                console.log('  • Try --debug flag or check Citrix website for changes.');
                console.log('============================================\n');
            } else if (!downloadResultGlobal.completed) {
                console.log("\nDownload monitor finished, but full completion wasn't confirmed by it.");
                console.log("Please check the download directory:", absoluteDownloadPath);
            }

            const shouldKeepAlive = downloadDetectedByMainLogic || (downloadResultGlobal && downloadResultGlobal.completed && downloadResultGlobal.files && downloadResultGlobal.files.length > 0);
            if (shouldKeepAlive) {
                if (!(downloadResultGlobal && downloadResultGlobal.message && downloadResultGlobal.message.includes('stalled')) && !(downloadResultGlobal && downloadResultGlobal.completed)) {
                    console.log('\nDownload may still be in progress or completed outside of active monitoring.');
                    console.log('Script will remain active. Press Ctrl+C to exit when download is finished.');
                } else if (downloadResultGlobal && downloadResultGlobal.completed) {
                    console.log('\nScript will remain active. Press Ctrl+C to exit.');
                }
                if (!args.headless) console.log("Browser will remain open. Close it manually if needed, or it will close on Ctrl+C.");
                await new Promise(() => { /* Keep alive */ });
            } else {
                console.log('Exiting script as no definitive download was detected or completed.');
            }

        } catch (e) {
            console.error(`Error during automation: ${e.message}`);
            if (args.debug) console.error(e.stack);
        } finally {
            // Use downloadResultGlobal here
            const finalDownloadDetected = downloadDetectedByMainLogic || (downloadResultGlobal && downloadResultGlobal.completed);
            if (puppeteerBrowser && puppeteerBrowser.isConnected()) {
                if (!args.debug && !finalDownloadDetected) {
                    console.log("Closing browser as no download was definitively started/completed and not in debug mode...");
                    await puppeteerBrowser.close();
                } else if (args.debug) {
                    console.log("Debug mode: Browser will not be closed automatically by this script section.");
                } else if (finalDownloadDetected && !args.headless) {
                    console.log("Browser might remain open due to active/completed download (non-headless). Close manually or via Ctrl+C.");
                } else if (finalDownloadDetected && args.headless) {
                    // In headless mode with a detected download, if we are not keeping script alive indefinitely,
                    // we might close. But the new Promise() above keeps it alive.
                    // If script is meant to exit, then: await puppeteerBrowser.close();
                }
            }
        }
    } catch (e) {
        console.error(`Failed to launch browser: ${e.message}`);
        if (args.debug) console.error(e.stack);
    } finally {
        console.log("Script execution finished or terminated by user.");
    }
}

downloadCitrix().catch(error => {
    console.error('Fatal error in downloadCitrix:', error.message);
    if (args.debug && error.stack) console.error(error.stack);
    process.exit(1);
});
