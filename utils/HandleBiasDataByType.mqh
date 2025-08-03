#ifndef __BIAS_DATA_BY_TYPE_MQH__
#define __BIAS_DATA_BY_TYPE_MQH__


// lấy mảng theo loại âm dương hoặc frozen theo loại

void getBiasArray(string arrayType, TicketInfo& result[]) {

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


void clearDataByType() {
   ArrayFree(negTicketList);
   ArrayFree(posTicketList);
   ArrayFree(frozTicketList);
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




ENUM_ORDER_TYPE getBiasOrderType(string biasType) {

   BiasConfig cfg;
   cfg.symbol = _Symbol;
   cfg.timeframe = biasType == DAILY_BIAS ? BIAS_TF_D1 : (biasType == H4_BIAS ? BIAS_TF_H4 : BIAS_TF_H1);
   BiasResult biasResult;
   biasResult = DetectBias(cfg);
   if (biasResult.type == "SELL") {
      isRunningBIAS = true;
      return ORDER_TYPE_SELL;
   }
   else if (biasResult.type == "BUY") {
      isRunningBIAS = true;
      return ORDER_TYPE_BUY;
   }
   else {
      if (biasTYPE == DAILY_BIAS)
      {
         startBias(H4_BIAS);
      }
      else if (biasTYPE == H4_BIAS)
      {
         startBias(H1_BIAS);
      }
      else
      {
         return NULL;
      }

   }
   return NULL;
}



#endif // __BIAS_DATA_BY_TYPE_MQH__