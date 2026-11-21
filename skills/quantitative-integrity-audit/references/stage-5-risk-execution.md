# Stage 5 Risk Execution

Check one trade per coin, four positions, 4.0x leverage, isolated margin, 1% equity risk, notional=0.01*equity/SL%, -5% daily kill switch, GTX entry, 1.2x ATR TP/SL and 60-minute timeout. Stress concurrent workers, partial fills, process restart, API timeout, retries, reduce-only exits, fee/funding PnL and boundary units. Never send exchange orders.
