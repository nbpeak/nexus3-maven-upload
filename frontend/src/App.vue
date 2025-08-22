<template>
  <div class="container mt-5">
    <h1 class="mb-4">Nexus Maven 构件上传工具</h1>

    <!-- Nexus Configuration -->
    <div class="card mb-4">
      <div class="card-header">Nexus 服务器配置</div>
      <div class="card-body">
        <form>
          <div class="row">
            <div class="col-md-6 mb-3">
              <label for="nexusUrl" class="form-label">Nexus 地址</label>
              <input type="text" class="form-control" id="nexusUrl" v-model="nexusConfig.url" placeholder="http://localhost:8081">
            </div>
            <div class="col-md-6 mb-3">
              <label for="repository" class="form-label">仓库名称</label>
              <input type="text" class="form-control" id="repository" v-model="nexusConfig.repository" placeholder="maven-releases">
            </div>
          </div>
          <div class="row">
            <div class="col-md-6 mb-3">
              <label for="username" class="form-label">用户名</label>
              <input type="text" class="form-control" id="username" v-model="nexusConfig.username">
            </div>
            <div class="col-md-6 mb-3">
              <label for="password" class="form-label">密码</label>
              <input type="password" class="form-control" id="password" v-model="nexusConfig.password">
            </div>
          </div>
        </form>
      </div>
    </div>

    <!-- File Upload Area -->
    <div class="card mb-4">
      <div class="card-header">选择 JAR 文件</div>
      <div class="card-body">
        <div 
          class="drop-zone text-center p-5" 
          @dragover.prevent="isDragging = true"
          @dragenter.prevent="isDragging = true"
          @dragleave.prevent="isDragging = false"
          @drop.prevent="handleFileDrop"
          :class="{ 'bg-light': isDragging }"
        >
          <p>拖拽 JAR 文件到此处，或者 <a href="#" @click.prevent="triggerFileInput">点击选择文件</a></p>
          <input type="file" ref="fileInput" @change="handleFileSelect" multiple accept=".jar" class="d-none">
        </div>
      </div>
    </div>

    <!-- Staged Files List -->
    <div v-if="stagedFiles.length > 0">
      <h3 class="mb-3">待上传文件</h3>
      <ul class="list-group mb-4">
        <li v-for="file in stagedFiles" :key="file.id" class="list-group-item">
          <div class="row align-items-center">
            <div class="col-md-3">
              <strong>{{ file.file.name }}</strong>
            </div>
            <div class="col-md-7">
              <div v-if="file.status === 'parsing'" class="text-muted">
                正在解析 pom.xml...
              </div>
              <div v-else>
                <div class="input-group mb-2">
                  <input type="text" class="form-control" placeholder="Group ID" v-model="file.groupId" :disabled="isUploading">
                  <input type="text" class="form-control" placeholder="Artifact ID" v-model="file.artifactId" :disabled="isUploading">
                  <input type="text" class="form-control" placeholder="Version" v-model="file.version" :disabled="isUploading">
                </div>
                <div v-if="file.version && file.version.includes('SNAPSHOT')" class="input-group">
                  <span class="input-group-text">时间戳</span>
                  <input type="text" class="form-control" placeholder="20250822.030923-1 (可选)" v-model="file.timestamp" :disabled="isUploading">
                  <span class="input-group-text">
                    <small class="text-muted">留空则自动生成</small>
                  </span>
                </div>
              </div>
            </div>
            <div class="col-md-2 text-end">
              <div class="d-flex align-items-center justify-content-end gap-2">
                <div>
                  <span v-if="file.status === 'pending'" class="badge bg-secondary">就绪</span>
                  <span v-if="file.status === 'parsing'" class="badge bg-info">解析中...</span>
                  <span v-if="file.status === 'uploading'" class="badge bg-primary">上传中...</span>
                  <span v-if="file.status === 'success'" class="badge bg-success">成功</span>
                  <span v-if="file.status === 'error'" class="badge bg-danger">{{ file.errorShortMessage || '错误' }}</span>
                </div>
                <button 
                  class="btn btn-outline-danger btn-sm" 
                  @click="removeFile(file.id)" 
                  :disabled="isUploading || file.status === 'uploading'"
                  title="删除文件"
                >
                  ×
                </button>
              </div>
            </div>
          </div>
          <div v-if="file.status === 'error'" class="row mt-2">
            <div class="col-md-12">
              <div class="alert alert-danger py-1 px-2 mb-0" style="font-size: 0.8em;">
                <strong>错误：</strong> {{ file.errorMessage }}
              </div>
            </div>
          </div>
        </li>
      </ul>
      <div class="d-grid gap-2 d-md-flex justify-content-md-center">
        <button class="btn btn-primary flex-grow-1" @click="uploadAllFiles" :disabled="isUploading || stagedFiles.some(f => f.status === 'parsing') || stagedFiles.length === 0">
          {{ isUploading ? '上传中...' : '上传全部' }}
        </button>
        <button class="btn btn-outline-secondary" @click="clearAllFiles" :disabled="isUploading || stagedFiles.length === 0">
          清空全部
        </button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, watch, reactive } from 'vue';
import axios from 'axios';

const nexusConfig = ref({ url: '', repository: '', username: '', password: '' });
const stagedFiles = ref([]);
const fileInput = ref(null);
const isUploading = ref(false);
const isDragging = ref(false);

onMounted(() => {
  const savedConfig = localStorage.getItem('nexusConfig');
  if (savedConfig) nexusConfig.value = JSON.parse(savedConfig);
});

watch(nexusConfig, (newConfig) => {
  localStorage.setItem('nexusConfig', JSON.stringify(newConfig));
}, { deep: true });

const triggerFileInput = () => fileInput.value.click();
const handleFileSelect = (event) => processFiles(event.target.files);
const handleFileDrop = (event) => {
  isDragging.value = false;
  processFiles(event.dataTransfer.files);
};

const processFiles = (files) => {
  console.log('Processing files:', files.length);
  [...files].forEach(file => {
    if (file.name.endsWith('.jar')) {
      console.log('Adding file:', file.name);
      const stagedFile = reactive({
        id: Date.now() + Math.random(),
        file: file,
        groupId: '',
        artifactId: '',
        version: '',
        timestamp: '', // For SNAPSHOT versions
        status: 'parsing',
        errorMessage: '',
        errorShortMessage: ''
      });
      stagedFiles.value.push(stagedFile);
      console.log('Current stagedFiles count:', stagedFiles.value.length);
      parseJarAndStage(stagedFile);
    }
  });
};

const parseJarAndStage = async (stagedFile) => {
  console.log('Starting to parse JAR:', stagedFile.file.name);
  console.log('Initial stagedFile status:', stagedFile.status);
  
  const formData = new FormData();
  formData.append('file', stagedFile.file);

  try {
    console.log('Sending request to /api/parse-jar');
    const response = await axios.post('/api/parse-jar', formData);
    console.log('Response received:', response.data);
    
    // Direct assignment works with reactive objects
    stagedFile.groupId = response.data.groupId;
    stagedFile.artifactId = response.data.artifactId;
    stagedFile.version = response.data.version;
    stagedFile.status = 'pending';
    
    console.log('Updated stagedFile:', stagedFile);
    console.log('New status:', stagedFile.status);
  } catch (error) {
    console.error('Failed to parse JAR:', error);
    const { artifactId, version } = parseFilename(stagedFile.file.name);
    stagedFile.status = 'error';
    stagedFile.errorMessage = error.response?.data?.message || '无法从 JAR 包中解析 pom.xml';
    stagedFile.errorShortMessage = '解析失败';
    stagedFile.artifactId = artifactId;
    stagedFile.version = version;
    console.log('Error - updated stagedFile:', stagedFile);
  }
};

const parseFilename = (filename) => {
  const stripped = filename.replace('.jar', '');
  const lastDashIndex = stripped.lastIndexOf('-');
  if (lastDashIndex === -1) return { artifactId: stripped, version: '' };
  return {
    artifactId: stripped.substring(0, lastDashIndex),
    version: stripped.substring(lastDashIndex + 1)
  };
};

const uploadAllFiles = async () => {
  isUploading.value = true;
  const uploadPromises = stagedFiles.value
    .filter(file => file.status !== 'success' && file.status !== 'uploading')
    .map(file => uploadFile(file));
  await Promise.all(uploadPromises);
  isUploading.value = false;
};

const uploadFile = async (file) => {
  file.status = 'uploading';
  file.errorMessage = '';
  file.errorShortMessage = '';

  const formData = new FormData();
  formData.append('file', file.file);
  formData.append('nexusUrl', nexusConfig.value.url);
  formData.append('repository', nexusConfig.value.repository);
  formData.append('username', nexusConfig.value.username);
  formData.append('password', nexusConfig.value.password);
  formData.append('groupId', file.groupId);
  formData.append('artifactId', file.artifactId);
  formData.append('version', file.version);
  formData.append('timestamp', file.timestamp || ''); // Send custom timestamp

  try {
    await axios.post('/api/upload', formData);
    file.status = 'success';
  } catch (error) {
    const nexusError = error.response?.data?.error;
    let errorMessage;
    if (typeof nexusError === 'string') {
      errorMessage = nexusError.split('\n')[0]; // Get the first line
    } else {
      errorMessage = error.response?.data?.message || `HTTP ${error.response?.status} Error`;
    }
    
    file.status = 'error';
    file.errorShortMessage = '上传失败';
    file.errorMessage = errorMessage || error.message;
    console.error(`Failed to upload ${file.file.name}:`, error);
  }
};

// Delete and reset functions
const removeFile = (fileId) => {
  const index = stagedFiles.value.findIndex(f => f.id === fileId);
  if (index !== -1) {
    stagedFiles.value.splice(index, 1);
  }
};

const clearAllFiles = () => {
  // Use splice to maintain reactivity instead of reassignment
  stagedFiles.value.splice(0, stagedFiles.value.length);
};
</script>

<style>
.drop-zone {
  border: 2px dashed #ccc;
  border-radius: 5px;
  cursor: pointer;
  transition: background-color 0.2s;
}
.drop-zone:hover, .drop-zone.bg-light {
  background-color: #f8f9fa;
}
</style>
