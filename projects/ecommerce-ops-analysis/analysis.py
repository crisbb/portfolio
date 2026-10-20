"""电商月度运营分析 · 可复现脚本
=================================
独立、无外部依赖（只需 pandas / numpy）。跑一遍即可复现简历里所有数字。

    pip install pandas numpy
    python3 analysis.py

数据：data/ 下 5 张 CSV（orders / users / products / returns / activity），模拟数据。
"""
import os
import pandas as pd

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, "data")


def load():
    orders = pd.read_csv(os.path.join(DATA, "orders.csv"), parse_dates=["order_date"])
    users = pd.read_csv(os.path.join(DATA, "users.csv"), parse_dates=["reg_date"])
    products = pd.read_csv(os.path.join(DATA, "products.csv"))
    activity = pd.read_csv(os.path.join(DATA, "activity.csv"), parse_dates=["act_date"])
    return orders, users, products, activity


def wide(orders, users, products):
    """订单为主表，左连用户属性、再左连品类成本率。"""
    return (
        orders.merge(users[["user_id", "reg_date", "city", "gender", "age"]],
                     on="user_id", how="left")
              .merge(products, on="category", how="left")
    )


def kpi(orders):
    print("\n【1 · 总览 KPI】")
    print(f"  总 GMV      = {orders['amount'].sum():,.2f}")
    print(f"  订单数      = {len(orders)}")
    print(f"  去重买家    = {orders['user_id'].nunique()}")
    print(f"  整体客单价  = {orders['amount'].mean():.2f}")
    print(f"  退款率(单量)= {orders['refunded'].mean()*100:.1f}%")


def by_channel(orders):
    g = orders.groupby("channel")["amount"].agg(["sum", "count"])
    g.columns = ["GMV", "订单数"]
    g["占比%"] = (g["GMV"] / g["GMV"].sum() * 100).round(1)
    print("\n【2 · 渠道结构】(GMV 降序)")
    print(g.sort_values("GMV", ascending=False).round(2).to_string())


def profit(w):
    w = w.assign(毛利=w["amount"] * (1 - w["cost_rate"]))
    g = w.groupby("category").agg(营收=("amount", "sum"), 毛利=("毛利", "sum"))
    g["毛利率%"] = (g["毛利"] / g["营收"] * 100).round(0)
    print("\n【3 · 利润视角】(毛利 降序) —— 营收≠利润")
    print(g.sort_values("毛利", ascending=False).round(2).to_string())


def retention(activity, users):
    a = activity.merge(users[["user_id", "reg_date"]], on="user_id", how="inner")
    a["第几天"] = (a["act_date"] - a["reg_date"]).dt.days
    den = a.loc[a["第几天"] == 0, "user_id"].nunique()
    print(f"\n【4 · 留存】分母(注册当天活跃去重用户) = {den}")
    for k in (1, 7, 30):
        num = a.loc[a["第几天"] == k, "user_id"].nunique()
        print(f"  D{k} = {num}/{den} = {num/den*100:.1f}%")


def simpson(orders):
    o = orders.assign(半月=pd.cut(orders["order_date"].dt.day,
                                  [0, 15, 31], labels=["上半月", "下半月"]))
    print("\n【5 · 辛普森悖论】整体客单价 vs 分渠道")
    overall = o.groupby("半月", observed=True)["amount"].mean().round(2)
    print(f"  整体客单价：{overall['上半月']} → {overall['下半月']}  (看着在跌)")
    ch = o.pivot_table(index="channel", columns="半月", values="amount",
                       aggfunc="mean", observed=True).round(2)
    print("  分渠道客单价（多数在涨）：")
    print(ch.to_string())
    share = o.pivot_table(index="channel", columns="半月", values="order_id",
                          aggfunc="count", observed=True)
    share = (share / share.sum() * 100).round(1)
    print("  分渠道单量占比%（高价渠道缩量才是真因）：")
    print(share.to_string())


def main():
    orders, users, products, activity = load()
    w = wide(orders, users, products)
    assert len(w) == len(orders), "join 掉行了"
    kpi(orders)
    by_channel(orders)
    profit(w)
    retention(activity, users)
    simpson(orders)
    print("\n✅ 全部指标复现完成。")


if __name__ == "__main__":
    main()
