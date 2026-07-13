import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const workspace = path.resolve(root, '..', '..')
const expectedMarketingVersion = '0.8.0'
const workflowPath = path.join(root, '.github', 'workflows', 'ios-ci.yml')
const contractSnapshotPath = path.join(root, 'ContractSnapshots', 'backend-api-v0.8.0.json')

const requiredFiles = [
  'project.yml',
  'ContractSnapshots/backend-api-v0.8.0.json',
  'UwayFinance/App/UwayFinanceApp.swift',
  'UwayFinance/Networking/APIEndpoint.swift',
  'UwayFinance/Networking/FinanceAPI.swift',
  'UwayFinance/Networking/ImportAnalysisAPI.swift',
  'UwayFinance/Networking/DocumentAPI.swift',
  'UwayFinance/Views/LedgerView.swift',
  'UwayFinance/Resources/Info.plist',
  'UwayFinance/Resources/Assets.xcassets/Contents.json',
  'UwayFinance/Resources/Assets.xcassets/AccentColor.colorset/Contents.json',
  'UwayFinance/Resources/Assets.xcassets/BrandGreen.colorset/Contents.json',
  'UwayFinanceTests/Fixtures/state-envelope.json',
  'UwayFinanceTests/AppConfigurationTests.swift',
  'UwayFinanceTests/AppSessionTests.swift',
  'UwayFinanceTests/Fixtures/harness-result.json',
  'UwayFinanceTests/Fixtures/import-analysis-request.json',
  'UwayFinanceTests/Fixtures/import-decision-response.json',
]

for (const file of requiredFiles) {
  if (!fs.existsSync(path.join(root, file))) throw new Error(`missing ${file}`)
}
if (!fs.existsSync(workflowPath)) throw new Error('missing .github/workflows/ios-ci.yml')

const fixtures = ['state-envelope.json', 'harness-result.json', 'import-analysis-request.json', 'import-decision-response.json']
for (const fixture of fixtures) {
  JSON.parse(fs.readFileSync(path.join(root, 'UwayFinanceTests', 'Fixtures', fixture), 'utf8'))
}

const decisionResponse = JSON.parse(fs.readFileSync(path.join(root, 'UwayFinanceTests', 'Fixtures', 'import-decision-response.json'), 'utf8'))
if (decisionResponse.status !== 'accepted') throw new Error('accepted human decision must keep Harness status accepted')
if (decisionResponse.resolution?.decision !== 'accept' || !decisionResponse.resolution?.reviewer) {
  throw new Error('human decision provenance must remain in resolution.decision/reviewer')
}

const contractSnapshot = JSON.parse(fs.readFileSync(contractSnapshotPath, 'utf8'))
if (contractSnapshot.version !== expectedMarketingVersion) throw new Error('backend contract snapshot version mismatch')
if (!['accepted', 'review', 'rejected'].every((status) => contractSnapshot.decisionStatuses.includes(status))) {
  throw new Error('backend contract snapshot must preserve Harness three-state status')
}

for (const asset of [
  'Contents.json',
  'AccentColor.colorset/Contents.json',
  'BrandGreen.colorset/Contents.json',
]) {
  JSON.parse(fs.readFileSync(path.join(root, 'UwayFinance', 'Resources', 'Assets.xcassets', asset), 'utf8'))
}

const plist = fs.readFileSync(path.join(root, 'UwayFinance', 'Resources', 'Info.plist'), 'utf8')
for (const marker of [
  '<?xml version="1.0" encoding="UTF-8"?>',
  '<plist version="1.0">',
  '</plist>',
  '<key>UWAY_API_SCHEME</key>',
  '<key>UWAY_API_HOST</key>',
  '<key>NSCameraUsageDescription</key>',
]) {
  if (!plist.includes(marker)) throw new Error(`Info.plist marker missing: ${marker}`)
}
if ((plist.match(/<string>/g) ?? []).length !== (plist.match(/<\/string>/g) ?? []).length) {
  throw new Error('Info.plist contains an unclosed string value')
}
if (!plist.includes('<key>CFBundleShortVersionString</key>') || !plist.includes('<string>$(MARKETING_VERSION)</string>')) {
  throw new Error('Info.plist must derive CFBundleShortVersionString from MARKETING_VERSION')
}

const project = fs.readFileSync(path.join(root, 'project.yml'), 'utf8')
if (!project.includes(`MARKETING_VERSION: ${expectedMarketingVersion}`)) {
  throw new Error(`project MARKETING_VERSION must be ${expectedMarketingVersion}`)
}
if (!project.includes('INFOPLIST_FILE: UwayFinance/Resources/Info.plist')) {
  throw new Error('project must reference the complete checked-in Info.plist without regenerating it')
}
if (!project.includes('ASSETCATALOG_COMPILER_APPICON_NAME: ""')) {
  throw new Error('project must not require an AppIcon set until production icon assets are added')
}
if (/\n\s+info:\s*\n\s+path: UwayFinance\/Resources\/Info\.plist/.test(project)) {
  throw new Error('XcodeGen info generation would overwrite custom runtime configuration')
}
for (const marker of [
  'path: UwayFinance/Resources/Assets.xcassets\n        buildPhase: resources',
  'path: UwayFinanceTests/Fixtures\n        buildPhase: resources',
]) {
  if (!project.includes(marker)) throw new Error(`project resource build phase missing: ${marker}`)
}
for (const configFile of ['Debug.xcconfig', 'Release.xcconfig']) {
  const config = fs.readFileSync(path.join(root, 'Config', configFile), 'utf8')
  if (!config.trim()) throw new Error(`${configFile} must not be empty`)
}

for (const marker of ['<string>https</string>', '<string>115.29.239.217</string>']) {
  if (!plist.includes(marker)) throw new Error(`Info.plist API configuration marker missing: ${marker}`)
}

const profile = fs.readFileSync(path.join(root, 'UwayFinance', 'Views', 'ProfileView.swift'), 'utf8')
for (const marker of ['Bundle.main', 'CFBundleShortVersionString', 'value: appVersion']) {
  if (!profile.includes(marker)) throw new Error(`Profile bundle version marker missing: ${marker}`)
}
if (profile.includes(`value: "${expectedMarketingVersion}"`)) {
  throw new Error('Profile version must not be hardcoded')
}

const swiftEndpoints = fs.readFileSync(path.join(root, 'UwayFinance', 'Networking', 'APIEndpoint.swift'), 'utf8')
const currentContracts = contractSnapshot.endpoints

for (const { method, path: endpoint, swift: swiftNeedle } of currentContracts) {
  if (!swiftEndpoints.includes(swiftNeedle)) throw new Error(`Swift endpoint missing: ${method.toUpperCase()} ${endpoint}`)
}

const importModels = fs.readFileSync(path.join(root, 'UwayFinance', 'Models', 'ImportModels.swift'), 'utf8')
for (const field of contractSnapshot.importRequestFields) {
  if (!importModels.includes(field)) throw new Error(`mainline import field mismatch: ${field}`)
}
if (importModels.includes('reviewerId')) throw new Error('reviewer identity must come from the authenticated server session')

const financeModels = fs.readFileSync(path.join(root, 'UwayFinance', 'Models', 'FinanceModels.swift'), 'utf8')
for (const field of contractSnapshot.ledgerProvenanceFields) {
  if (!financeModels.includes(field)) throw new Error(`ledger provenance field mismatch: ${field}`)
}

const serverPath = path.join(workspace, 'server', 'index.ts')
const importSchemaPath = path.join(workspace, 'server', 'import-analysis.ts')
const stateSchemaPath = path.join(workspace, 'server', 'schema.ts')
const hasLocalBackend = process.env.UWAY_SKIP_LOCAL_BACKEND !== '1'
  && [serverPath, importSchemaPath, stateSchemaPath].every(fs.existsSync)
if (hasLocalBackend) {
  const server = fs.readFileSync(serverPath, 'utf8')
  for (const { method, path: endpoint } of currentContracts) {
    if (!server.includes(`app.${method}('${endpoint}'`)) throw new Error(`local server endpoint missing: ${method.toUpperCase()} ${endpoint}`)
  }
  const importSchema = fs.readFileSync(importSchemaPath, 'utf8')
  for (const field of contractSnapshot.importRequestFields) {
    if (!importSchema.includes(field)) throw new Error(`local import schema mismatch: ${field}`)
  }
  const stateSchema = fs.readFileSync(stateSchemaPath, 'utf8')
  for (const field of contractSnapshot.ledgerProvenanceFields) {
    if (!stateSchema.includes(field)) throw new Error(`local state schema mismatch: ${field}`)
  }
}

const ledger = fs.readFileSync(path.join(root, 'UwayFinance', 'Views', 'LedgerView.swift'), 'utf8')
if (!ledger.includes('fixedControls') || !ledger.includes('ledgerScroll')) throw new Error('ledger fixed/scroll boundary missing')
if (ledger.includes('pinnedViews:')) throw new Error('month headings must not be sticky')

const workflow = fs.readFileSync(workflowPath, 'utf8')
for (const marker of [
  'runs-on: macos-26',
  'uses: actions/checkout@v7',
  'xcodegen generate --spec project.yml',
  'build-for-testing',
  'Verify built API configuration',
  'test-without-building',
  'CODE_SIGNING_ALLOWED=NO',
  'uses: actions/upload-artifact@v7',
]) {
  if (!workflow.includes(marker)) throw new Error(`iOS CI marker missing: ${marker}`)
}

console.log(`validated iOS ${expectedMarketingVersion}: ${requiredFiles.length} files, ${currentContracts.length} API contracts, ${fixtures.length} JSON fixtures, macOS CI${hasLocalBackend ? ', local backend cross-check' : ''}`)
