import express from 'express'
import { exec } from 'child_process'
import { stat } from 'fs/promises'
import { promisify } from 'util'
import path from 'path'
import { fileURLToPath } from 'url'

const execAsync = promisify(exec)
const __dirname = path.dirname(fileURLToPath(import.meta.url))
const app = express()
const PORT = 1299
const API_KEY = process.env.API_KEY

app.use(express.json())

app.use((req, res, next) => {
  if (req.headers['x-api-key'] !== API_KEY)
    return res.status(403).json({ error: 'Forbidden' })
  next()
})

const SWIFT_SOURCE = path.join(__dirname, 'add-contact.swift')
const BINARY_PATH = path.join(__dirname, 'add-contact')

async function ensureBinary() {
  try {
    const srcStat = await stat(SWIFT_SOURCE)
    let needsBuild = true
    try {
      const binStat = await stat(BINARY_PATH)
      if (binStat.mtimeMs >= srcStat.mtimeMs) needsBuild = false
    } catch {}

    if (needsBuild) {
      console.log('Compiling add-contact binary...')
      await execAsync(`swiftc "${SWIFT_SOURCE}" -o "${BINARY_PATH}"`)
      console.log('✅ Binary compiled')
    }
  } catch (err) {
    console.error('Failed to compile binary:', err)
    process.exit(1)
  }
}

async function triggerContactsPermission() {
  console.log('Triggering Contacts permission check...')
  try {
    // Run the binary with dummy args — this triggers TCC dialog if not yet granted
    const { stdout, stderr } = await execAsync(`${BINARY_PATH} "_PermCheck" "_Trigger" "+10000000000" ""`)
    console.log('Permission check result:', stdout.trim())
    
    // Clean up the dummy contact
    await execAsync(`${BINARY_PATH} --delete "_PermCheck" "_Trigger"`).catch(() => {})
  } catch (err) {
    console.log('Permission not yet granted. macOS should show a dialog.')
    console.log('Click "OK" on the dialog, then retry your API call.')
  }
}

app.post('/create-contact', async (req, res) => {
  const { user, firstName, lastName, email, phone } = req.body

  if (!user || !firstName || !lastName || !phone)
    return res.status(400).json({ error: 'Missing required fields' })

  const escape = (s) => `"${String(s).replace(/"/g, '\\"')}"`
  const args = [firstName, lastName, phone, email || ''].map(escape).join(' ')
  const cmd = `sudo -u ${user} ${BINARY_PATH} ${args}`

  exec(cmd, (err, stdout, stderr) => {
    console.log('CMD:', cmd)
    console.log('STDOUT:', stdout)
    console.log('STDERR:', stderr)
    if (err) return res.status(500).json({
      error: stderr || stdout || err.message,
      stdout, stderr, code: err.code
    })
    res.json({ success: true, message: stdout.trim() })
  })
})

await ensureBinary()
await triggerContactsPermission()
app.listen(PORT, () => console.log(`Agent running on :${PORT}`))