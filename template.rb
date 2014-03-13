# my custom monitoring configuration for applications other than rails

# run in non-daemonized mode (so you can monitor it) with `god -c /path/to/mysql.god -D`
# run normally with `god -c /path/to/mysql.god`

# the workers will have a name like such beanstalk-worker-app_directory ie beanstalk-worker-development

# Settings for email notifications (optional)
God::Contacts::Email.defaults do |d|
  d.from_email = 'god@myapp.com'
  d.from_name = 'God'
  d.delivery_method = :sendmail # this can also be :smtp
  # d.server_host = 'smtp.myapp.com'
  # d.server_port = 25
  # d.server_auth = true
  # d.server_domain = 'myapp.com'
  # d.server_user = 'smtp_user@myapp.com'
  # d.server_password = 'password'
end

# you can create as many email entries as you'd like
God.contact(:email) do |c|
  c.name = 'Developer 1'
  c.group = 'developers'
  c.to_email = 'developer@example.com'
end

directory = File.dirname(__FILE__).split(File::SEPARATOR)

APP_ROOT = directory.slice(0, directory.size-2).join(File::SEPARATOR)
APP_NAME = directory.slice(directory.size-3)

God.watch do |w|
    # polling interval
    w.interval = 30.seconds
    w.name = "something-#{APP_NAME}"
    w.log = "#{APP_ROOT}/log/god.log"
    # example of running a php file
    w.start = "php #{APP_ROOT}/worker.php"
    
    # how long to wait after starting service before monitoring resumes
    w.start_grace = 20.seconds

    # how long to wait after restarting service before monitoring resumes
    w.restart_grace = 20.seconds
    
    w.keepalive
    
    # determine the state on startup
    w.transition(:init, { true => :up, false => :start }) do |on|
        on.condition(:process_running) do |c|
            c.running = true
        end
    end
    
    # determine when process has finished starting
    w.transition([:start, :restart], :up) do |on|
        on.condition(:process_running) do |c|
            c.running = true
        end
        # failsafe
        on.condition(:tries) do |c|
            c.times = 8
            c.within = 2.minutes
            c.transition = :start
        end
    end
    
    # start if process is not running
    w.transition(:up, :start) do |on|
        on.condition(:process_exits) do |c|
            # send an email to me to notify me that the service has crashed
            c.notify = {:contacts => ['developers'], :priority => 1 }
        end
    end
    
    # lifecycle
    w.lifecycle do |on|
        # If the service keeps triggering a restart over and over, it is considered to be "flapping".
        on.condition(:flapping) do |c|
            c.to_state = [:start, :restart]
            c.times = 5
            c.within = 1.minute
            c.transition = :unmonitored
            # If the service is flapping, wait 10 minutes, then try to start/restart again.
            c.retry_in = 10.minutes
            c.retry_times = 5
            c.retry_within = 2.hours
        end
    end
end

