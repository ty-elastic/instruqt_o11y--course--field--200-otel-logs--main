package com.example.recorder;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

import java.lang.management.GarbageCollectorMXBean;
import java.lang.management.ManagementFactory;
import java.util.HashMap;
import java.util.Map;

import org.springframework.stereotype.Service;
import org.springframework.transaction.TransactionStatus;
import org.springframework.transaction.annotation.*;
import org.springframework.transaction.interceptor.TransactionAspectSupport;

import ch.qos.logback.classic.pattern.Util;

/**
 * Service layer is where all the business logic lies
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class TradeRecorder {
    
    private final Utilities utilities;
    private final TradeRepo tradeRepo;
    private boolean pgStatEnabled = false;

    @Transactional
    public Trade recordTrade (Trade trade){
        if (!pgStatEnabled) {
            try {
                log.atInfo().log("enabling pg_stat_statements");
                tradeRepo.enablePGStatStatements();
            }
            catch (Exception e) {
                log.atWarn().log(e.getMessage());
                if (e.getMessage().contains("already exists")) {
                    pgStatEnabled = true;
                }
            }
        }

        Trade savedTrade = tradeRepo.save(trade);

        log.atInfo().addKeyValue(Main.ATTRIBUTE_PREFIX + ".gc_time", utilities.getGarbageCollectorDeltaTime()).log("trade committed for " + trade.customerId);

        return savedTrade;
    }
}
