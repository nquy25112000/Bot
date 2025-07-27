#!/bin/bash

# ---- CONFIG ----
MT5_FOLDER_WIN="C:\\Program Files\\MetaTrader 5"
MT5_FOLDER_MAC="/Applications/MetaTrader 5"
TESTER_EXE="metatester64.exe"
CONFIG_FILE="XAUUSDm_config.ini"

# ---- OS detection ----
OS_TYPE="$(uname -s)"

if [[ "$OS_TYPE" == "Darwin" ]]; then
  echo "[🔵 macOS] Running backtest with Wine..."
  WINE_PATH=$(which wine)
  if [ -z "$WINE_PATH" ]; then
    echo "[❌] Wine not found! Run: brew install --cask wine-stable"
    exit 1
  fi

  # Customize the actual path on your mac here
  WINE_MT5_PATH="$MT5_FOLDER_MAC/$TESTER_EXE"
  WINE_CONFIG_PATH="$(pwd)/$CONFIG_FILE"

  wine "$WINE_MT5_PATH" /portable /config:"$WINE_CONFIG_PATH"

elif [[ "$OS_TYPE" == "MINGW"* || "$OS_TYPE" == "CYGWIN"* || "$OS_TYPE" == "MSYS"* || "$OS_TYPE" == "Windows_NT" ]]; then
  echo "[🟢 Windows] Running backtest natively..."
  MT5_PATH="$MT5_FOLDER_WIN\\$TESTER_EXE"
  CONFIG_PATH="$(pwd)\\$CONFIG_FILE"

  # Double quotes to handle spaces in path
  "$MT5_PATH" /portable /config:"$CONFIG_PATH"

else
  echo "[❌] Unsupported OS: $OS_TYPE"
  exit 1
fi
