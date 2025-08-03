#ifndef __BIAS_DATA_BY_TYPE_MQH__
#define __BIAS_DATA_BY_TYPE_MQH__


// lấy mảng theo loại âm dương hoặc frozen theo loại

void getBiasArray(string arrayType,TicketInfo& result[]) {

   if (arrayType == POSITIVE_ARRAY)
      copyTicketArray(posTicketList, result);
   else if (arrayType == NEGATIVE_ARRAY)
      copyTicketArray(negTicketList, result);
   else if (arrayType == FROZEN_ARRAY)
      copyTicketArray(frozTicketList, result);
   else
      ArrayFree(result);
}


void updateBiasArray(string arrayType, TicketInfo& result[]) {
   if (arrayType == POSITIVE_ARRAY)
      copyTicketArray(result, posTicketList);
   else if (arrayType == NEGATIVE_ARRAY)
      copyTicketArray(result, negTicketList);
   else if (arrayType == FROZEN_ARRAY)
      copyTicketArray(result, frozTicketList);
}

void copyTicketArray(TicketInfo& source[], TicketInfo& destination[]) {
   int size = ArraySize(source);
   ArrayResize(destination, size);
   for (int i = 0; i < size; i++) {
      destination[i] = source[i];
   }
}

void updateDailyBiasArray(string arrayType, TicketInfo& result[]) {
   if (arrayType == POSITIVE_ARRAY)
      copyTicketArray(posTicketList, result);
   else if (arrayType == NEGATIVE_ARRAY)
      copyTicketArray(negTicketList, result);
   else if (arrayType == FROZEN_ARRAY)
      copyTicketArray(frozTicketList, result);
}


void clearDataByType(string biasType) {
   ArrayFree(negTicketList);
   ArrayFree(posTicketList);
   ArrayFree(frozTicketList);
}

// thêm phần tử vào mảng các mảng theo loại để xác định ticket nào thuộc loại nào
void AddTicketIdByType(string biasType, ulong ticketId) {
   AddTicketIdToArray(D1_ticketIds, ticketId);
}

// Thêm phần tử vào mảng
void AddTicketIdToArray(ulong& arr[], ulong value) {
   int size = ArraySize(arr);
   ArrayResize(arr, size + 1);
   arr[size] = value;
}

// lấy danh sách volume negative theo type
void GetVolumeNegativeByType(string biasType, double& destination[]) {
   if (biasType == DAILY_BIAS) {
      ArrayCopy(destination, negD1volumes);
   }
   else if (biasType == H4_BIAS) {
      ArrayCopy(destination, negH4volumes);
   }
   else if (biasType == H1_BIAS) {
      ArrayCopy(destination, negH1volumes);
   }
}

void setFirstEntryByBiasType(string biasType, double firstEntry) {
   if (biasType == DAILY_BIAS) {
      initEntryD1 = firstEntry;
   }
   else if (biasType == H4_BIAS) {
      initEntryD1 = firstEntry; // cần viết lại firstEntry cho H4
   }
   else if (biasType == H1_BIAS) {
      initEntryD1 = firstEntry; // cần viết lại firstEntry cho H1
   }
}



ENUM_ORDER_TYPE getBiasOrderType(string biasType) {

   BiasConfig cfg;
   cfg.symbol = _Symbol;
   cfg.timeframe = biasType == DAILY_BIAS ? BIAS_TF_D1 : (biasType == H4_BIAS ? BIAS_TF_H4 : BIAS_TF_H1);
   BiasResult biasResult = DetectBias(cfg);
   if (biasResult.type == "SELL") {
      return ORDER_TYPE_SELL;
   }
   else if (biasResult.type == "BUY") {
      return ORDER_TYPE_BUY;
   }
   else {
      return "NONE";
   }
}


double getPriceFirstEntryByBiasType(string biasType) {
   if (biasType == DAILY_BIAS) {
      return initEntryD1;
   }
   else if (biasType == H4_BIAS) {
      return initEntryH4;
   }
   else if (biasType == H1_BIAS) {
      return initEntryH1;
   }
   return 0;
}

string getBiasTypeByTicketId(ulong ticketId) {
   for (uint i = 0; i < D1_ticketIds.Size(); i++) {
      if (ticketId == D1_ticketIds[i]) {
         return DAILY_BIAS;
      }
   }
   for (uint i = 0; i < H4_ticketIds.Size(); i++) {
      if (ticketId == H4_ticketIds[i]) {
         return H4_BIAS;
      }
   }
   for (uint i = 0; i < H1_ticketIds.Size(); i++) {
      if (ticketId == H1_ticketIds[i]) {
         return H1_BIAS;
      }
   }
   return NULL;
}

#endif __BIAS_DATA_BY_TYPE_MQH__