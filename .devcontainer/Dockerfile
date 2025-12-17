FROM debian:bullseye-slim

SHELL ["/bin/bash", "-c"]

# 必要パッケージ追加（procps追加）
RUN apt-get update && \
    apt-get install -y curl git wget unzip zip xz-utils sudo procps && \
    rm -rf /var/lib/apt/lists/*

# 開発者ユーザーを追加
RUN useradd -ms /bin/bash developer \
    && echo "developer ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

ENV HOME=/home/developer
WORKDIR $HOME

# Java(Zulu OpenJDK)
ENV JAVA_HOME=/opt/zulu17.56.15-ca-jdk17.0.14-linux_x64
RUN wget -P /tmp/ https://cdn.azul.com/zulu/bin/zulu17.56.15-ca-jdk17.0.14-linux_x64.zip && \
    unzip /tmp/zulu17.56.15-ca-jdk17.0.14-linux_x64.zip -d /opt && \
    rm -rf /tmp/*

ENV PATH=$JAVA_HOME/bin:$PATH

# Android SDK
ENV ANDROID_SDK_ROOT=/opt/Android/sdk
ENV ANDROID_HOME=$ANDROID_SDK_ROOT
RUN mkdir -p ${ANDROID_SDK_ROOT}/cmdline-tools

RUN wget -P /tmp https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip && \
    unzip /tmp/commandlinetools-linux-11076708_latest.zip -d ${ANDROID_SDK_ROOT}/cmdline-tools/ && \
    mv ${ANDROID_SDK_ROOT}/cmdline-tools/cmdline-tools ${ANDROID_SDK_ROOT}/cmdline-tools/latest && \
    rm -rf /tmp/*

ENV PATH=${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin:${ANDROID_SDK_ROOT}/platform-tools:${ANDROID_SDK_ROOT}/platforms:$PATH

# Flutter SDK
ENV FLUTTER_ROOT=/opt/flutter
RUN wget -P /tmp https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.24.4-stable.tar.xz && \
    tar -xf /tmp/flutter_linux_3.24.4-stable.tar.xz -C /opt/ && \
    rm -rf /tmp/*

ENV PATH=${FLUTTER_ROOT}/bin:$PATH

# 権限修正（とても重要）
RUN chown -R developer:developer /opt /home/developer

USER developer
WORKDIR $HOME

# Android SDK コンポーネント
RUN yes | sdkmanager --sdk_root=$ANDROID_SDK_ROOT "platform-tools" "platforms;android-34" "build-tools;33.0.1"

# ライセンス同意 & Telemetry 無効化
RUN yes | flutter doctor --android-licenses && \
    flutter --disable-analytics

CMD ["/bin/bash"]
