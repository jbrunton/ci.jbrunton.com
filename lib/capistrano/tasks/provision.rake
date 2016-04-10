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
          # git plugin dependencies
          ['credentials', '1.24'],
          ['git-client', '1.19.0'],
          ['scm-api', '1.0'],
          ['mailer', '1.16'],
          ['matrix-project', '1.6'],
          ['ssh-credentials', '1.11'],

          # git plugin
          ['git', '2.4.0']
        ].each do |plugin|
          name, version = plugin
          execute <<-END
            java -jar jenkins-cli.jar \
              -s http://localhost:8080/ \
              install-plugin \
              http://updates.jenkins-ci.org/download/plugins/#{name}/#{version}/#{name}.hpi
          END
        end
      end
    end

    Rake::Task[:install_plugins].enhance do
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
  Rake::Task["provision:sonar:install"].invoke
end
