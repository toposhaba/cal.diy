const { execSync } = require('child_process');

const targetOrg = process.env.SF_TARGET_ORG || 'CALDIYDev';
try {
    const result = JSON.parse(
        execSync(`sf org open --target-org ${targetOrg} --url-only --json`, {
            encoding: 'utf8',
            timeout: 30000,
            stdio: ['pipe', 'pipe', 'pipe']
        })
    );
    process.stdout.write(result.result.url);
} catch (e) {
    process.stderr.write('Failed to get frontdoor URL: ' + e.message + '\n');
    process.exit(1);
}
