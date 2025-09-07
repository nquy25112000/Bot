import pytz, datetime as dt
from apscheduler.schedulers.background import BackgroundScheduler
from .service import scan
from .config import TIMEZONE
tz = pytz.timezone(TIMEZONE)
sched = BackgroundScheduler(timezone=TIMEZONE)
def _before_14h(): return dt.datetime.now(tz).time() < dt.time(14,0)
def _job():        _before_14h() and scan()
def start():       sched.add_job(_job,'cron',hour=7,minute=0); sched.start()
