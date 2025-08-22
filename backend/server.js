const express = require('express');
const multer = require('multer');
const axios = require('axios');
const path = require('path');
const AdmZip = require('adm-zip');
const xml2js = require('xml2js');

const app = express();
const port = 3000;

// Serve static files from public directory
app.use(express.static(path.join(__dirname, 'public')));

const storage = multer.memoryStorage();
const upload = multer({ storage: storage });

// Endpoint to parse pom.xml from a JAR file
app.post('/api/parse-jar', upload.single('file'), async (req, res) => {
  if (!req.file) {
    return res.status(400).send('No file uploaded.');
  }

  try {
    const zip = new AdmZip(req.file.buffer);
    const pomEntry = zip.getEntries().find(entry => entry.entryName.match(/META-INF\/maven\/.*\/*.pom.xml$/));

    if (!pomEntry) {
      return res.status(404).send({ message: 'Could not find pom.xml in the JAR file.' });
    }

    const pomXmlContent = zip.readAsText(pomEntry);
    const parser = new xml2js.Parser();
    const pomData = await parser.parseStringPromise(pomXmlContent);

    const project = pomData.project;
    const groupId = project.groupId?.[0] || project.parent?.[0]?.groupId?.[0];
    const artifactId = project.artifactId?.[0];
    const version = project.version?.[0] || project.parent?.[0]?.version?.[0];

    if (!groupId || !artifactId || !version) {
        return res.status(400).send({ message: 'Failed to parse essential coordinates from pom.xml.' });
    }

    res.status(200).send({ groupId, artifactId, version });

  } catch (error) {
    console.error('Error parsing JAR:', error);
    res.status(500).send({ message: 'Error parsing JAR file.', error: error.message });
  }
});


// Enhanced endpoint to upload JAR and its internal POM
app.post('/api/upload', upload.single('file'), async (req, res) => {
  const { nexusUrl, repository, username, password, groupId, artifactId, version, timestamp } = req.body;
  const file = req.file;

  if (!file) {
    return res.status(400).send('No file uploaded.');
  }

  // --- Logic from shell script ---
  let remoteJarFilename = file.originalname;
  let remotePomFilename = remoteJarFilename.replace('.jar', '.pom');

  // Smart SNAPSHOT naming
  if (version.endsWith('-SNAPSHOT') && !remoteJarFilename.match(/\d{8}\.\d{6}-\d+/)) {
    console.log("Processing SNAPSHOT artifact...");
    
    let finalTimestamp;
    if (timestamp && timestamp.trim()) {
      // Use custom timestamp provided by user
      finalTimestamp = timestamp.trim();
      console.log("Using custom timestamp:", finalTimestamp);
    } else {
      // Generate automatic timestamp
      const now = new Date();
      const datePart = now.toISOString().slice(0, 10).replace(/-/g, '');
      const timePart = now.toISOString().slice(11, 19).replace(/:/g, '');
      const buildNumber = 1; // Default build number
      finalTimestamp = `${datePart}.${timePart}-${buildNumber}`;
      console.log("Generated automatic timestamp:", finalTimestamp);
    }
    
    const versionBase = version.replace('-SNAPSHOT', '');
    remoteJarFilename = `${artifactId}-${versionBase}-${finalTimestamp}.jar`;
    remotePomFilename = remoteJarFilename.replace('.jar', '.pom');
  }
  // --- End of shell script logic ---

  const groupPath = groupId.replace(/\./g, '/');
  const baseUploadUrl = `${nexusUrl}/repository/${repository}/${groupPath}/${artifactId}/${version}`;
  const jarUploadUrl = `${baseUploadUrl}/${remoteJarFilename}`;
  const pomUploadUrl = `${baseUploadUrl}/${remotePomFilename}`;

  console.log(`Attempting to upload JAR to: ${jarUploadUrl}`);

  try {
    // 1. Upload the JAR file
    const jarUploadResponse = await axios.put(jarUploadUrl, file.buffer, {
      auth: { username, password },
      headers: { 'Content-Type': 'application/java-archive' },
    });

    console.log('JAR upload successful.');

    // 2. Extract and upload the pom.xml
    const zip = new AdmZip(file.buffer);
    const pomEntry = zip.getEntries().find(entry => entry.entryName.match(/META-INF\/maven\/.*\/*.pom.xml$/));
    if (pomEntry) {
      const pomXmlContent = zip.readAsText(pomEntry);
      console.log(`Attempting to upload POM to: ${pomUploadUrl}`);
      await axios.put(pomUploadUrl, pomXmlContent, {
        auth: { username, password },
        headers: { 'Content-Type': 'application/xml' },
      });
      console.log('POM upload successful.');
    } else {
      console.warn('No pom.xml found in JAR, skipping POM upload.');
    }

    res.status(jarUploadResponse.status).send({ message: 'Artifacts uploaded successfully.' });

  } catch (error) {
    console.error('Error during upload:', error.message);
    const status = error.response?.status || 500;
    const data = error.response?.data || { message: 'An internal server error occurred.' };
    res.status(status).send({ message: 'Upload failed.', error: data });
  }
});

// Handle SPA routing - serve index.html for all non-API routes
app.get('*', (req, res) => {
  if (!req.path.startsWith('/api')) {
    res.sendFile(path.join(__dirname, 'public', 'index.html'));
  }
});

app.listen(port, () => {
  console.log(`Unified server listening at http://localhost:${port}`);
});
