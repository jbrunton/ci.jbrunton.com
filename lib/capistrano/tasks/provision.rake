namespace :provision do
  task :apt_update do
    on roles(:web) do
      execute <<-END
        apt-get install -y software-properties-common
        apt-add-repository ppa:brightbox/ruby-ng
        apt-get update
      END
    end
  end

  task :install_binaries do
    on roles(:web) do
      execute "apt-get install -y lib32stdc++6 lib32z1"
    end
  end

  task :install_java do
    on roles(:web) do
      execute <<-END
        echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | debconf-set-selections
        add-apt-repository -y ppa:webupd8team/java
        apt-get update
        apt-get install -y oracle-java6-installer
        apt-get install -y oracle-java8-installer
        rm -rf /var/lib/apt/lists/*
        rm -rf /var/cache/oracle-jdk6-installer
        rm -rf /var/cache/oracle-jdk8-installer
        echo "JAVA_HOME=/usr/lib/jvm/java-8-oracle" >> /etc/environment
        echo "JAVA6_HOME=/usr/lib/jvm/java-6-oracle" >> /etc/environment
      END
    end
  end

  task :install_jenkins do
    on roles(:web) do
      execute <<-END
        wget -q -O - https://jenkins-ci.org/debian/jenkins-ci.org.key | sudo apt-key add -
        sudo sh -c 'echo deb http://pkg.jenkins-ci.org/debian binary/ > /etc/apt/sources.list.d/jenkins.list'
        sudo apt-get update
        sudo apt-get install -y jenkins
        echo "JENKINS_HOME=#{fetch :jenkins_home}" >> /etc/environment
      END
    end
  end

  task :install_git do
    on roles(:web) do
      execute "sudo apt-get install -y git"
    end
  end

  task :install_android_sdk do
    on roles(:web) do
      execute <<-END
        cd #{fetch :jenkins_home}
        wget http://dl.google.com/android/android-sdk_r24.4.1-linux.tgz
        tar -xvf android-sdk_r24.4.1-linux.tgz
        chown -R jenkins:jenkins .
        echo "ANDROID_HOME=$JENKINS_HOME/android-sdk-linux" >> /etc/environment
      END
    end
  end

  namespace :jenkins do
    task :restart do
      on roles(:web) do
        execute "sudo java -jar jenkins-cli.jar -s http://localhost:8080/ safe-restart"
      end
    end

    task :install_cli do
      on roles(:web) do
        execute_script <<-END
          wget http://localhost:8080/jnlpJars/jenkins-cli.jar
          while [ $? -ne 0 ];
          do
            echo "Waiting for Jenkins to start..."
            sleep 10
            wget http://localhost:8080/jnlpJars/jenkins-cli.jar
          done
        END
      end
    end

    task :install_plugins => [:install_cli] do
      on roles(:web) do
        [
          ['git', 'latest'],
          ['github', 'latest'],
          ['ghprb', 'latest']
        ].each do |plugin|
          name, version = plugin
          execute <<-END
            curl -X POST -d \
              '<jenkins><install plugin="#{name}@#{version}" /></jenkins>' \
              --header 'Content-Type: text/xml' \
              http://localhost:8080/pluginManager/installNecessaryPlugins
          END
          execute_script <<-END
            while [ ! -d #{fetch :jenkins_home}/plugins/#{name} ];
            do
              echo "Waiting for plugin #{name} to be installed..."
              sleep 5
            done
            echo "#{name} plugin installed."
          END
        end
      end
    end

    Rake::Task[:install_plugins].enhance do
      Rake::Task['provision:jenkins:restart'].invoke
    end

    task :configure_jobs do
      on roles(:web) do
        execute "mkdir -p /tmp/jobs"
        ['pocket-timeline-android (push)', 'pocket-timeline-android (pull)'].each do |job_name|
          upload! "config/jobs/#{job_name}.xml", "/tmp/jobs/#{job_name}.xml"
          execute <<-END
            java -jar jenkins-cli.jar \
              -s http://localhost:8080/ \
              create-job #{job_name} < /tmp/jobs/#{job_name}.xml
          END
        end
      end
    end

    Rake::Task[:configure_jobs].enhance do
      Rake::Task['provision:jenkins:restart'].invoke
    end
  end

  namespace :sonar do
    task :install do
      on roles(:web) do
        execute <<-END
          echo "deb http://downloads.sourceforge.net/project/sonar-pkg/deb binary/" >> /etc/apt/sources.list
          apt-get update
          sudo apt-get install -y --force-yes sonar
          /opt/sonar/bin/linux-x86-64/sonar.sh start
        END
      end
    end
  end
end

desc "Provision the server"
task :provision do
  Rake::Task["provision:apt_update"].invoke
  Rake::Task["provision:install_binaries"].invoke
  Rake::Task["provision:install_java"].invoke
  Rake::Task["provision:install_jenkins"].invoke
  Rake::Task["provision:install_git"].invoke
  Rake::Task["provision:install_android_sdk"].invoke
  Rake::Task["provision:jenkins:install_plugins"].invoke
  Rake::Task["provision:jenkins:configure_jobs"].invoke
  Rake::Task["provision:sonar:install"].invoke
end
