import express from 'express'
import { exec } from 'child_process'
import { writeFile, unlink } from 'fs/promises'
import { randomUUID } from 'crypto'
import { promisify } from 'util'
import os from 'os'
import path from 'path'

const execAsync = promisify(exec)
const app = express()
const PORT = 1299
const API_KEY = process.env.API_KEY

app.use(express.json())

app.use((req, res, next) => {
  if (req.headers['x-api-key'] !== API_KEY)
    return res.status(403).json({ error: 'Forbidden' })
  next()
})

async function runScript(user, script) {
  const tmpFile = path.join(os.tmpdir(), `script-${randomUUID()}.scpt`)
  await writeFile(tmpFile, script)
  try {
    const { stdout } = await execAsync(`sudo -u ${user} env -i HOME=/Users/${user} osascript ${tmpFile}`)
    return stdout.trim()
  } finally {
    await unlink(tmpFile).catch(() => {})
  }
}

async function ensureContactsHealthy(user) {
  try {
    await runScript(user, `tell application "Contacts" to count of people`)
  } catch {
    // Contacts is stale — kill and relaunch
    await execAsync(`sudo -u ${user} killall Contacts`).catch(() => {})
    await new Promise(r => setTimeout(r, 1500))
    await execAsync(`sudo -u ${user} launchctl asuser $(id -u ${user}) open -a Contacts`).catch(() => {})
    await new Promise(r => setTimeout(r, 2000))
  }
}

app.post('/create-contact', async (req, res) => {
  const { user, firstName, lastName, email, phone } = req.body

  if (!user || !firstName || !lastName || !phone)
    return res.status(400).json({ error: 'Missing required fields' })

  const emailLine = email
    ? `make new email with properties {label:"work", value:"${email}"}`
    : ''

  const script = `tell application "Contacts"
    set newPerson to make new person with properties {first name:"${firstName}", last name:"${lastName}"}
    tell newPerson
        ${emailLine}
        make new phone with properties {label:"mobile", value:"${phone}"}
    end tell
    save
    return "Contact created successfully"
end tell`

  try {
    await ensureContactsHealthy(user)
    const result = await runScript(user, script)
    res.json({ success: true, message: result })
  } catch (err) {
    res.status(500).json({ error: String(err.stderr || err.message || err) })
  }
})

app.listen(PORT, () => console.log(`Agent running on :${PORT}`))