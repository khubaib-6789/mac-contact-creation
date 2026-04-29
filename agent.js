import express from 'express'
import { exec } from 'child_process'
import { mkdir, readFile, stat } from 'fs/promises'
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
const INFO_PLIST = path.join(__dirname, 'Info.plist')
const APP_PATH = path.join(__dirname, 'MacAgentContactHelper.app')
const BINARY_PATH = path.join(APP_PATH, 'Contents', 'MacOS', 'add-contact')
const APP_PLIST_PATH = path.join(APP_PATH, 'Contents', 'Info.plist')
const CURRENT_USER = process.env.USER

async function ensureBinary() {
  try {
    const srcStat = await stat(SWIFT_SOURCE)
    const plistStat = await stat(INFO_PLIST)
    let needsBuild = true
    try {
      const binStat = await stat(BINARY_PATH)
      if (binStat.mtimeMs >= srcStat.mtimeMs && binStat.mtimeMs >= plistStat.mtimeMs) needsBuild = false
    } catch {}

    if (needsBuild) {
      console.log('Compiling add-contact binary...')
      await mkdir(path.dirname(BINARY_PATH), { recursive: true })
      await execAsync(`cp "${INFO_PLIST}" "${APP_PLIST_PATH}"`)
      await execAsync(`swiftc "${SWIFT_SOURCE}" -o "${BINARY_PATH}" -Xlinker -sectcreate -Xlinker __TEXT -Xlinker __info_plist -Xlinker "${INFO_PLIST}"`)
      console.log('✅ Binary compiled')
    }
  } catch (err) {
    console.error('Failed to compile binary:', err)
    process.exit(1)
  }
}

async function getUserId(user) {
  if (!/^[A-Za-z0-9._-]+$/.test(user)) {
    throw new Error('Invalid user')
  }

  const { stdout } = await execAsync(`id -u "${user}"`)
  return stdout.trim()
}

app.post('/create-contact', async (req, res) => {
  const { user, firstName, lastName, email, phone } = req.body

  if (!user || !firstName || !lastName || !phone)
    return res.status(400).json({ error: 'Missing required fields' })

  const escape = (s) => `"${String(s).replace(/"/g, '\\"')}"`
  const resultPath = path.join('/tmp', `mac-agent-contact-${Date.now()}-${Math.random().toString(16).slice(2)}.json`)
  const args = [firstName, lastName, phone, email || '', '--result', resultPath].map(escape).join(' ')
  let cmd

  try {
    const uid = await getUserId(user)
    cmd = user === CURRENT_USER
      ? `/usr/bin/open -W -n "${APP_PATH}" --args ${args}`
      : `sudo -u "${user}" /bin/launchctl asuser ${uid} /usr/bin/open -W -n "${APP_PATH}" --args ${args}`
  } catch (err) {
    return res.status(400).json({ error: err.message })
  }

  exec(cmd, async (err, stdout, stderr) => {
    console.log('CMD:', cmd)
    console.log('STDOUT:', stdout)
    console.log('STDERR:', stderr)
    let result = null
    try {
      result = JSON.parse(await readFile(resultPath, 'utf8'))
    } catch {}

    if (err || !result?.success) return res.status(500).json({
      error: result?.error || stderr || stdout || err?.message || 'Contact helper failed',
      stdout,
      stderr,
      code: err?.code
    })
    res.json({ success: true, message: result.message || 'Contact created successfully' })
  })
})

await ensureBinary()
app.listen(PORT, () => console.log(`Agent running on :${PORT}`))