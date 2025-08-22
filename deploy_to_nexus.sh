#!/bin/bash

# Nexus3配置
NEXUS_URL="http://10.10.10.10:8081"
REPOSITORY="maven-hosted"
USERNAME="abc"  # 请替换为您的用户名
PASSWORD="123123"  # 请替换为您的密码

# 提示用户输入JAR文件路径
read -p "请输入要上传的jar包路径: " JAR_FILE

# 检查文件是否存在
if [ ! -f "$JAR_FILE" ]; then
    echo "错误: 文件不存在 $JAR_FILE"
    exit 1
fi

echo "正在解析jar包信息..."

# 从路径中解析Maven坐标
# 假设路径结构为 .../.m2/repository/group/path/artifact/version/file.jar
# 使用realpath确保我们有绝对路径
JAR_FULL_PATH=$(realpath "$JAR_FILE")
JAR_FILENAME=$(basename "$JAR_FULL_PATH")
JAR_DIR=$(dirname "$JAR_FULL_PATH")
VERSION=$(basename "$JAR_DIR")
ARTIFACT_ID=$(basename "$(dirname "$JAR_DIR")")

# 提取GROUP_PATH, 这是在/repository/和/ARTIFACT_ID/VERSION之间的部分
REPO_BASE_PATH_PART="/.m2/repository/"
if [[ "$JAR_DIR" != *"$REPO_BASE_PATH_PART"* ]]; then
    echo "错误: jar包路径看起来不像是来自一个标准的Maven本地仓库 (.m2/repository/)"
    echo "无法自动解析 group ID."
    exit 1
fi
# 使用字符串操作提取Group Path
GROUP_AND_ARTIFACT_PATH=${JAR_DIR#*"$REPO_BASE_PATH_PART"}
GROUP_PATH=${GROUP_AND_ARTIFACT_PATH%/"$ARTIFACT_ID"/"$VERSION"}
GROUP_ID=$(echo "$GROUP_PATH" | tr '/' '.')

echo "----------------------------------------"
echo "解析出的信息如下:"
echo "  Group ID:    $GROUP_ID"
echo "  Artifact ID: $ARTIFACT_ID"
echo "  Version:     $VERSION"
echo "----------------------------------------"

# 提示用户确认或修改版本
read -p "请确认版本号 [$VERSION] (可直接回车或输入新版本): " NEW_VERSION
if [ -n "$NEW_VERSION" ]; then
    VERSION=$NEW_VERSION
    echo "版本已修改为: $VERSION"
fi

# 初始化远程文件名
REMOTE_JAR_FILENAME=$JAR_FILENAME
REMOTE_POM_FILENAME="${JAR_FILENAME%.jar}.pom"

# 如果是SNAPSHOT版本，且原始文件名是非时间戳格式，则生成时间戳文件名
if [[ "$VERSION" == *-SNAPSHOT && "$JAR_FILENAME" == *"-SNAPSHOT.jar" ]]; then
    echo "检测到非时间戳的SNAPSHOT包，将自动生成时间戳..."
    TIMESTAMP=$(date -u +'%Y%m%d.%H%M%S')
    BUILD_NUMBER=1 # 默认构建号为1
    VERSION_BASE=${VERSION%-SNAPSHOT} # 移除-SNAPSHOT后缀
    
    REMOTE_JAR_FILENAME="${ARTIFACT_ID}-${VERSION_BASE}-${TIMESTAMP}-${BUILD_NUMBER}.jar"
    REMOTE_POM_FILENAME="${ARTIFACT_ID}-${VERSION_BASE}-${TIMESTAMP}-${BUILD_NUMBER}.pom"
    
    echo "将使用的远程文件名: $REMOTE_JAR_FILENAME"
fi


# 构建上传URL
BASE_UPLOAD_URL="$NEXUS_URL/repository/$REPOSITORY/$GROUP_PATH/$ARTIFACT_ID/$VERSION"
JAR_UPLOAD_URL="$BASE_UPLOAD_URL/$REMOTE_JAR_FILENAME"

echo "----------------------------------------"
echo "开始上传..."
echo "  本地文件: $JAR_FULL_PATH"
echo "  上传 URL: $JAR_UPLOAD_URL"
echo "----------------------------------------"

# 创建一个临时文件来存储服务器响应
RESPONSE_FILE=$(mktemp)

# 使用curl上传文件，并将HTTP状态码写入变量 (单行命令)
HTTP_CODE=$(curl -s -w '%{http_code}' -o "$RESPONSE_FILE" -u "$USERNAME:$PASSWORD" --upload-file "$JAR_FULL_PATH" "$JAR_UPLOAD_URL")

# 检查上传结果
if [ "$HTTP_CODE" -eq 200 ] || [ "$HTTP_CODE" -eq 201 ]; then
    echo "✅ jar包上传成功! (状态码: $HTTP_CODE)"
else
    echo "❌ jar包上传失败! (状态码: $HTTP_CODE)"
    echo "---------- 服务器响应 ----------"
    cat "$RESPONSE_FILE"
    echo "---------------------------------"
    rm -f "$RESPONSE_FILE"
    exit 1
fi

# 清理临时文件
rm -f "$RESPONSE_FILE"


# 查找并上传对应的pom文件
POM_FILE="${JAR_FULL_PATH%.jar}.pom"
if [ -f "$POM_FILE" ]; then
    POM_UPLOAD_URL="$BASE_UPLOAD_URL/$REMOTE_POM_FILENAME"
    echo "发现pom文件，正在上传... ($POM_UPLOAD_URL)"
    
    RESPONSE_FILE_POM=$(mktemp)
    # 单行命令
    HTTP_CODE_POM=$(curl -s -w '%{http_code}' -o "$RESPONSE_FILE_POM" -u "$USERNAME:$PASSWORD" --upload-file "$POM_FILE" "$POM_UPLOAD_URL")
        
    if [ "$HTTP_CODE_POM" -eq 200 ] || [ "$HTTP_CODE_POM" -eq 201 ]; then
        echo "✅ pom文件上传成功! (状态码: $HTTP_CODE_POM)"
    else
        echo "❌ pom文件上传失败! (状态码: $HTTP_CODE_POM)"
        echo "---------- 服务器响应 ----------"
        cat "$RESPONSE_FILE_POM"
        echo "---------------------------------"
    fi
    rm -f "$RESPONSE_FILE_POM"
else
    echo "ℹ️  未找到对应的pom文件 ($POM_FILE)"
fi

echo "上传完成!"
