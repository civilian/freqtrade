# pragma pylint: disable=missing-docstring, invalid-name, pointless-string-statement
import numpy as np
import pandas as pd
from pandas import DataFrame

from freqtrade.strategy import IStrategy
import talib.abstract as ta
from datetime import datetime
from freqtrade.persistence import Trade


class AdvancedMomentumStrategy(IStrategy):
    """
    Estrategia avanzada combinando PSAR, ROC, RSI y ATR
    """
    INTERFACE_VERSION: int = 3

    # Configuración general
    timeframe = '1h'
    stoploss = -0.2
    use_custom_stoploss = True

    # Parámetros de la estrategia
    minimal_roi = {
        "0": 0.10,  # Take Profit al 10%
    }
    custom_info = {}

    # Indicadores personalizados
    def populate_indicators(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
        # Indicadores de tendencia
        dataframe['ema_short'] = ta.EMA(dataframe['close'], timeperiod=9)
        dataframe['ema_long'] = ta.EMA(dataframe['close'], timeperiod=21)

        # Indicador de momentum
        dataframe['roc'] = ta.ROC(dataframe['close'], timeperiod=5)

        # RSI para evitar entradas en sobrecompra
        dataframe['rsi'] = ta.RSI(dataframe['close'], timeperiod=14)

        # PSAR para trailing stop
        dataframe['sar'] = ta.SAR(dataframe)

        # ATR para medir la volatilidad
        dataframe['atr'] = ta.ATR(dataframe)

        return dataframe

    # Entradas: comprar en tendencias alcistas con momentum alto
    def populate_entry_trend(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
        dataframe.loc[
            (
                (dataframe['ema_short'] > dataframe['ema_long']) &  # Tendencia alcista
                (dataframe['roc'] > 2) &  # Subida rápida (> 2%)
                (dataframe['rsi'] < 70)  # RSI no en sobrecompra
            ),
            'enter_long'] = 1
        return dataframe

    # Salidas: vender cuando el precio esté en sobrecompra o momentum decaiga
    def populate_exit_trend(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
        dataframe.loc[
            (
                (dataframe['rsi'] > 70) |  # RSI en sobrecompra
                (dataframe['roc'] < -2)  # Bajada rápida (< -2%)
            ),
            'exit_long'] = 1
        return dataframe

    # Stop-loss dinámico con PSAR
    def custom_stoploss(self, pair: str, trade: 'Trade', current_time: datetime,
                        current_rate: float, current_profit: float, **kwargs) -> float:
        result = 1
        if self.custom_info and pair in self.custom_info and trade:
            relative_sl = None
            if self.dp:
                dataframe, _ = self.dp.get_analyzed_dataframe(pair=pair, timeframe=self.timeframe)
                last_candle = dataframe.iloc[-1].squeeze()
                relative_sl = last_candle['sar']

            if relative_sl is not None:
                new_stoploss = (current_rate - relative_sl) / current_rate
                result = new_stoploss - 1

        return result
