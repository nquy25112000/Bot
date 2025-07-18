#!/usr/bin/env bash

# Script: fix_bug.sh
# Mục đích: sửa chữ ký InitVolumes để thêm & trước mảng sourceVolumes

FILE="data/MarketDataService.mqh"

# 1. Sao lưu file gốc
cp "$FILE" "${FILE}.bak"

# 2. Chỉnh sửa chữ ký hàm
# Tìm dòng bắt đầu bằng void InitVolumes(…sourceVolumes[], int size, int inJump)
# và chèn & trước sourceVolumes[]
sed -i.bak -E \
  's#^(\s*void InitVolumes\()\s*const double\s*sourceVolumes\[\],#\1const double &sourceVolumes[],#' \
  "$FILE"

echo "✅ Đã sửa chữ ký InitVolumes trong $FILE"
echo "   Bản gốc lưu tại ${FILE}.bak"