---
title: Bundle File Structure
sort_info: 700
---

<div class="note" markdown="1">
The result of this tutorial can be found in bundles/tutorials if you
followed the instructions at the bottom of [this page](../tutorials/index.html).
While the tip of the master branch contains the accumulated result of all the
tutorials, you can get the specific result of this one by checking out the
bundle-file-structure tag with
~~~
git checkout bundle-file-structure
~~~
</div>

All these tutorials were dealing with "everything in a file". We felt that it
was a better way to understand how everything fits together.

However, as we saw [in the leader-follower tutorial](600_more_complex.html), we
want to be able to share and reuse the models and definitions. Moreover, having
everything in a single file obviously does not scale very well ...

This page will simply introduce where all the bits and pieces are stored in a
given bundle, as well as additional concepts that were not introduced in the
tutorials.

When starting from a given bundle, the syskit application will __automatically__
load all model files contained in said bundle. Therefore, when creating scripts
in scripts/, all the models defined in models/ __are__ available. The
modifications described in this page will therefore break the scripts (there
will be duplicate definitions). For this reason, the result of the modifications
described on this page are contained on a different package than the one in
which the script-based tutorials we just did is stored. Go into
bundles/tutorials (instead of bundles/tutorials_scripts)

Blueprints
----------
[Data services](../system/data_services.html) and
[compositions](../system/compositions.html) are defined in models/blueprints.
They must:

 - require any other bundle file they need (as e.g. to get definitions for other
   compositions and/or data services)
 - use import_types_from 'typekit' to get the type definitions for the types it
   needs (in data service definitions). The name of the typekit can be obtained
   with rock-inspect (the "defined in XXX" line), or on the website / in
   rock-browse on the type page.
 - use using_task_library 'project ' for the task contexts. The project name is
   in oroGen the same than the task context namespace (e.g. 'motor_controller'
   for 'motor_controller::Task')
 
The file name should by convention be the name of the model defined and the
namespace the same than the bundle name (the rock bundle is an exception here,
as it defines common models for all packages in Rock).

For instance, the scripts/04_leader_follower.rb script would be split into:

__models/blueprints/command_generator_srv.rb__:

~~~ ruby
import_types_from 'base'
module Tutorials
  data_service_type 'CommandGeneratorSrv' do
    output_port 'cmd', '/base/MotionCommand2D'
  end
end
~~~

__models/blueprints/rock_control.rb__

~~~ ruby
require 'rock/models/blueprints/pose'
require 'models/blueprints/command_generator_srv'
using_task_library 'rock_tutorial'
module Tutorials
  class RockControl < Syskit::Composition
    add CommandGeneratorSrv, :as => "cmd"
    add RockTutorial::RockTutorialControl, :as => "rock"
    cmd_child.connect_to rock_child

    conf 'slow',
        cmd_child => ['default', 'slow']

    export rock_child.pose_samples_port
    provides Base::PoseSrv, :as => 'pose'
  end
end
~~~


Task Context Modelling
----------------------

The main models for the task contexts are automatically generated by Syskit
based on the oroGen description. What we did in these tutorials was "extending"
these models, most often to declare that they provide some data service.

These extensions are declared in files in models/orogen/, where file names must
be the name of the corresponding oroGen project. These files are loaded
automatically whenever the corresponding oroGen project is. As for with files in
models/blueprints, the relevant data services must be explicitely required in
these files. No need to use import_types_from and/or using_task_library: the
relevant typekits and type libraries are already loaded.

The _provides_ lines in scripts/04_leader_follower.rb would therefore be split
into four files:

__models/orogen/controldev.rb__

~~~ ruby
require 'models/blueprints/command_generator_srv'
Controldev::JoystickTask.provides Tutorials::CommandGeneratorSrv, :as => 'cmd'
~~~

__models/orogen/tut_brownian.rb__

~~~ ruby
require 'models/blueprints/command_generator_srv'
TutBrownian::Task.provides Tutorials::CommandGeneratorSrv, :as => 'cmd'
~~~

__models/orogen/tut_follower.rb__

~~~ ruby
require 'models/blueprints/command_generator_srv'
TutFollower::Task.provides Tutorials::CommandGeneratorSrv, :as => 'cmd'
~~~

Specializations
---------------
A specialization can either be given along with the specialized composition or
within the relevant oroGen extension file (in config/orogen). There is currently
no clear winner when considering discoverability or reusability.

Let's assume we put it with the composition. Modify
__models/blueprints/rock_control.rb__ so that the end of the RockControl class
definition looks like:

~~~ ruby
module Tutorials
  class RockControl < Syskit::Composition
    [snip]

    specialize cmd_child => TutFollower::Task do
      add Base::PoseSrv, :as => "target_pose"
      add TutSensor::Task, :as => 'sensor'

      target_pose_child.connect_to sensor_child.target_frame_port
      rock_child.connect_to sensor_child.local_frame_port
      sensor_child.connect_to cmd_child
    end
  end
end
~~~

Since this specialization refers to TutFollower::Task and TutSensor::Task, you will also have to add

~~~ ruby
using_task_library 'tut_follower'
using_task_library 'tut_sensor'
~~~

at the top of the file

Definitions
-----------

Definitions are declared in [profiles](../system/profiles.html), Profiles are
set of predefined actions that can be injected in relevant Syskit applications
by 'using' them in an action interface.

The profile is defined within a namespace that matches the bundle name, in
models/profiles/. The file name should be the name of the profile.

__models/profiles/rocks.rb__

~~~ ruby
require 'models/blueprints/rock_control'
using_task_library 'controldev'
using_task_library 'tut_brownian'
using_task_library 'tut_follower'
module Tutorials
  profile 'Rocks' do
    define 'joystick',    Tutorials::RockControl.use(Controldev::JoystickTask)
    define 'random',      Tutorials::RockControl.use(TutBrownian::Task)
    define 'random_slow', Tutorials::RockControl.use(TutBrownian::Task.with_conf('default', 'slow'))
    define 'random_slow2', Tutorials::RockControl.use(TutBrownian::Task).with_conf('slow')
    define 'leader',
      Tutorials::RockControl.use(TutBrownian::Task).
        use_deployments(/target/)
    define 'follower',
      Tutorials::RockControl.use(TutFollower::Task, leader_def).
        use_deployments(/follower/)
  end
end
~~~

The 'main' action interface is already defined in models/actions/main.rb. You
simply have to declare that you want to use the new profile:

__models/actions/main.rb__

~~~ ruby
require 'models/profiles/rocks'
class Main < Roby::Actions::Interface
  use_profile Tutorials::Rocks
end
~~~
    
Deployments
-----------
Finally, deployments are 'used' in the robot's config file or in config/init.rb.
When it is in init.rb, it must be done after the Roby.app.using 'syskit' line.

First, let's add a 'tut' robot

~~~
# roby add-robot tut
~~~

And edit its main configuration file:

__config/tut.rb__

~~~ ruby
Syskit.conf.use_deployments_from 'tut_deployment'
~~~

Finally
-------

You can finally use syskit run, syskit browse and syskit instanciate. syskit
browse does not need any arguments. run and instanciate will need you to specify
a -rtut argument, to tell roby that you want the 'tut' configuration to
be loaded:

~~~
syskit run -rtut follower!
~~~

Reusing other Bundles
---------------------
In order to not have to re-model everything each time you create a new
application, models can be shared across bundles. This is done by adding a
_dependency_ from a bundle to another.

In our case, we will reuse the models that come with Rock's core bundle,
bundles/rock. Edit config/bundle.yml (the file [we previously
deleted](100_moving_to_bundles.html#create-the-bundle) and add

~~~ yaml
bundle:
    dependencies:
        - rock
~~~

(note, this is the default content in all new bundles)

Run syskit browse (and ignore the error in skid4_control.rb, we'll fix that in
the next tutorial). If you look into the producers of
Types::Base::MotionCommand2D, you will find Base::Motion2DControllerSrv. Which
fits our components (we generate control commands of type Motion2D).
We should therefore reuse this service instead of defining our own.

Delete models/blueprints/command_generator_srv.rb, and replace all occurences of

~~~ ruby
require 'models/blueprints/command_generator_srv'
~~~

by (as reported by syskit browse)

~~~ ruby
require 'rock/models/blueprints/control'
~~~

as well as all occurences of

~~~ ruby
Tutorials::CommandGeneratorSrv (or plain CommandGeneratorSrv, depending)
~~~

by

~~~ ruby
Base::Motion2DControllerSrv
~~~

The next necessary step, in order to have a new completely functional bundle
again, is to have a look at devices. This is the subject [of the next
tutorial](800_devices.html)