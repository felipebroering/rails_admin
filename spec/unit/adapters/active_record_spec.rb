require 'spec_helper'
require 'rails_admin/adapters/active_record'


describe RailsAdmin::Adapters::ActiveRecord do
  before do
    @like = ::ActiveRecord::Base.configurations[Rails.env]['adapter'] == "postgresql" ? 'ILIKE' : 'LIKE'
  end

  describe '#associations' do
    before :all do
      RailsAdmin::AbstractModel.reset_polymorphic_parents

      class ARBlog < ActiveRecord::Base
        has_many :a_r_posts
        has_many :a_r_comments, :as => :commentable
      end

      class ARPost < ActiveRecord::Base
        belongs_to :a_r_blog
        has_and_belongs_to_many :a_r_categories
        has_many :a_r_comments, :as => :commentable
      end

      class ARCategory < ActiveRecord::Base
        has_and_belongs_to_many :a_r_posts
      end

      class ARUser < ActiveRecord::Base
        has_one :a_r_profile
      end

      class ARProfile < ActiveRecord::Base
        belongs_to :a_r_user
      end

      class ARComment < ActiveRecord::Base
        belongs_to :commentable, :polymorphic => true
      end

      @blog = RailsAdmin::AbstractModel.new(ARBlog)
      @post = RailsAdmin::AbstractModel.new(ARPost)
      @category = RailsAdmin::AbstractModel.new(ARCategory)
      @user = RailsAdmin::AbstractModel.new(ARUser)
      @profile = RailsAdmin::AbstractModel.new(ARProfile)
      @comment = RailsAdmin::AbstractModel.new(ARComment)
    end

    after :all do
      RailsAdmin::AbstractModel.reset_polymorphic_parents
    end

    it 'lists associations' do
      @post.associations.map{|a|a[:name].to_s}.sort.should == ['a_r_blog', 'a_r_categories', 'a_r_comments']
    end

    it 'list associations types in supported [:belongs_to, :has_and_belongs_to_many, :has_many, :has_one]' do
      (@post.associations + @blog.associations + @user.associations).map{|a|a[:type]}.uniq.map(&:to_s).sort.should == ['belongs_to', 'has_and_belongs_to_many', 'has_many', 'has_one']
    end

    it "has correct parameter of belongs_to association" do
      param = @post.associations.select{|a| a[:name] == :a_r_blog}.first
      param.reject{|k, v| [:child_model_proc, :parent_model_proc].include? k }.should == {
        :name=>:a_r_blog,
        :pretty_name=>"A r blog",
        :type=>:belongs_to,
        :parent_key=>[:id],
        :child_key=>:a_r_blog_id,
        :foreign_type=>nil,
        :as=>nil,
        :polymorphic=>nil,
        :inverse_of=>nil,
        :read_only=>nil,
        :nested_form=>nil
      }
      param[:child_model_proc].call.should == ARPost
      param[:parent_model_proc].call.should == ARBlog
    end

    it "has correct parameter of has_many association" do
      param = @blog.associations.select{|a| a[:name] == :a_r_posts}.first
      param.reject{|k, v| [:child_model_proc, :parent_model_proc].include? k }.should == {
        :name=>:a_r_posts,
        :pretty_name=>"A r posts",
        :type=>:has_many,
        :parent_key=>[:id],
        :child_key=>:ar_blog_id,
        :foreign_type=>nil,
        :as=>nil,
        :polymorphic=>nil,
        :inverse_of=>nil,
        :read_only=>nil,
        :nested_form=>nil
      }
      param[:child_model_proc].call.should == ARPost
      param[:parent_model_proc].call.should == ARBlog
    end

    it "has correct parameter of has_and_belongs_to_many association" do
      param = @post.associations.select{|a| a[:name] == :a_r_categories}.first
      param.reject{|k, v| [:child_model_proc, :parent_model_proc].include? k }.should == {
        :name=>:a_r_categories,
        :pretty_name=>"A r categories",
        :type=>:has_and_belongs_to_many,
        :parent_key=>[:id],
        :child_key=>:ar_post_id,
        :foreign_type=>nil,
        :as=>nil,
        :polymorphic=>nil,
        :inverse_of=>nil,
        :read_only=>nil,
        :nested_form=>nil
      }
      param[:child_model_proc].call.should == ARCategory
      param[:parent_model_proc].call.should == ARPost
    end

    it "has correct parameter of polymorphic belongs_to association" do
      RailsAdmin::Config.stub!(:models_pool).and_return(["ARBlog", "ARPost", "ARCategory", "ARUser", "ARProfile", "ARComment"])
      param = @comment.associations.select{|a| a[:name] == :commentable}.first
      param.reject{|k, v| [:child_model_proc, :parent_model_proc].include? k }.should == {
        :name=>:commentable,
        :pretty_name=>"Commentable",
        :type=>:belongs_to,
        :parent_key=>[:id],
        :child_key=>:commentable_id,
        :foreign_type=>:commentable_type,
        :as=>nil,
        :polymorphic=>true,
        :inverse_of=>nil,
        :read_only=>nil,
        :nested_form=>nil
      }
      param[:child_model_proc].call.should == ARComment
      param[:parent_model_proc].call.should == [ARBlog, ARPost]
    end
  end

  describe "#properties" do
    before do
      @abstract_model = RailsAdmin::AbstractModel.new('Player')
    end

    it "returns parameters of string-type field" do
      @abstract_model.properties.select{|f| f[:name] == :name}.should ==
        [{:name => :name, :pretty_name => "Name", :type => :string, :length => 100, :nullable? => false, :serial? => false}]
    end
  end

  describe "data access method" do
    before do
      @players = FactoryGirl.create_list(:player, 3)
      @abstract_model = RailsAdmin::AbstractModel.new('Player')
    end

    it "#new returns instance of AbstractObject" do
      @abstract_model.new.object.should be_instance_of(Player)
    end

    it "#get returns instance of AbstractObject" do
      @abstract_model.get(@players.first.id).object.should == @players.first
    end

    it "#get returns nil when id does not exist" do
      @abstract_model.get('abc').should be_nil
    end

    it "#first returns first item" do
      @abstract_model.first.should == @players.first
    end

    it "#count returns count of items" do
      @abstract_model.count.should == @players.count
    end

    it "#destroy destroys multiple items" do
      @abstract_model.destroy(@players[0..1])
      Player.all.should == @players[2..2]
    end

    describe "#all" do
      it "works without options" do
        @abstract_model.all.sort.should == @players.sort
      end

      it "supports eager loading" do
        @abstract_model.all(:include => :team).includes_values.should == [:team]
      end

      it "supports limiting" do
        @abstract_model.all(:limit => 2).count.should == 2
      end

      it "supports retrieval by bulk_ids" do
        @abstract_model.all(:bulk_ids => @players[0..1].map{|player| player.id }).
          sort.should == @players[0..1].sort
      end

      it "supports pagination" do
        @abstract_model.all(:page => 2, :per => 1).should == @players[1..1]
      end

      it "supports ordering" do
        @abstract_model.all(:sort => "id", :sort_reverse => true).should == @players.sort
      end

      it "supports querying" do
        @abstract_model.all(:query => @players[1].name).should == @players[1..1]
      end

      it "supports filtering" do
        @abstract_model.all(:filters => {"name" => {"0000" => {:o=>"is", :v=>@players[1].name}}}).should == @players[1..1]
      end
    end
  end

  describe "#query_conditions" do
    before do
      @abstract_model = RailsAdmin::AbstractModel.new('Ball')
    end

    it "returns query statement" do
      @abstract_model.send(:query_conditions, "word").should == ["(balls.color LIKE ?) OR (balls.type LIKE ?)", "%word%", "%word%"]
    end
  end

  describe "#filter_conditions" do
    before do
      @abstract_model = RailsAdmin::AbstractModel.new('Team')
    end

    it "returns filter statement" do
      @abstract_model.send(
        :filter_conditions,
        {"name" => {"0000" => {:o=>"is", :v=>"Jets"}},
         "division" => {"0001" => {:o=>"like", :v=>"1"}}}
      ).should == ["((teams.name #{@like} ?)) AND ((divisions.name #{@like} ?) OR (teams.division_id = ?))", "Jets", "%1%", 1]
    end
  end

  describe "#build_statement" do
    before do
      @abstract_model = RailsAdmin::AbstractModel.new('Team')
    end

    it "ignores '_discard' operator or value" do
      [["_discard", ""], ["", "_discard"]].each do |value, operator|
        @abstract_model.send(:build_statement, :name, :string, value, operator).should be_nil
      end
    end

    it "supports '_blank' operator" do
      [["_blank", ""], ["", "_blank"]].each do |value, operator|
        @abstract_model.send(:build_statement, :name, :string, value, operator).should == ["(name IS NULL OR name = '')"]
      end
    end

    it "supports '_present' operator" do
      [["_present", ""], ["", "_present"]].each do |value, operator|
        @abstract_model.send(:build_statement, :name, :string, value, operator).should == ["(name IS NOT NULL AND name != '')"]
      end
    end

    it "supports '_null' operator" do
      [["_null", ""], ["", "_null"]].each do |value, operator|
        @abstract_model.send(:build_statement, :name, :string, value, operator).should == ["(name IS NULL)"]
      end
    end

    it "supports '_not_null' operator" do
      [["_not_null", ""], ["", "_not_null"]].each do |value, operator|
        @abstract_model.send(:build_statement, :name, :string, value, operator).should == ["(name IS NOT NULL)"]
      end
    end

    it "supports '_empty' operator" do
      [["_empty", ""], ["", "_empty"]].each do |value, operator|
        @abstract_model.send(:build_statement, :name, :string, value, operator).should == ["(name = '')"]
      end
    end

    it "supports '_not_empty' operator" do
      [["_not_empty", ""], ["", "_not_empty"]].each do |value, operator|
        @abstract_model.send(:build_statement, :name, :string, value, operator).should == ["(name != '')"]
      end
    end

    it "supports boolean type query" do
      ['false', 'f', '0'].each do |value|
        @abstract_model.send(:build_statement, :field, :boolean, value, nil).should == ["(field IS NULL OR field = ?)", false]
      end
      ['true', 't', '1'].each do |value|
        @abstract_model.send(:build_statement, :field, :boolean, value, nil).should == ["(field = ?)", true]
      end
      @abstract_model.send(:build_statement, :field, :boolean, 'word', nil).should be_nil
    end

    it "supports integer type query" do
      @abstract_model.send(:build_statement, :field, :integer, "1", nil).should == ["(field = ?)", 1]
      @abstract_model.send(:build_statement, :field, :integer, 'word', nil).should be_nil
    end

    it "supports string type query" do
      @abstract_model.send(:build_statement, :field, :string, "", nil).should be_nil
      @abstract_model.send(:build_statement, :field, :string, "foo", "was").should be_nil
      @abstract_model.send(:build_statement, :field, :string, "foo", "default").should == ["(field #{@like} ?)", "%foo%"]
      @abstract_model.send(:build_statement, :field, :string, "foo", "like").should == ["(field #{@like} ?)", "%foo%"]
      @abstract_model.send(:build_statement, :field, :string, "foo", "starts_with").should == ["(field #{@like} ?)", "foo%"]
      @abstract_model.send(:build_statement, :field, :string, "foo", "ends_with").should == ["(field #{@like} ?)", "%foo"]
      @abstract_model.send(:build_statement, :field, :string, "foo", "is").should == ["(field #{@like} ?)", "foo"]
    end

    [:datetime, :timestamp, :date].each do |type|
      it "supports #{type} query" do
        @abstract_model.send(:build_statement, :field, type, "", "default").should be_nil
        @abstract_model.send(:build_statement, :field, type, "", "is").should be_nil
        @abstract_model.send(:build_statement, :field, type, "", "today").should ==
          ["(field BETWEEN ? AND ?)", Date.today.beginning_of_day, Date.today.end_of_day]
        @abstract_model.send(:build_statement, :field, type, "", "yesterday").should ==
          ["(field BETWEEN ? AND ?)", Date.yesterday.beginning_of_day, Date.yesterday.end_of_day]
        @abstract_model.send(:build_statement, :field, type, "", "this_week").should ==
          ["(field BETWEEN ? AND ?)", Date.today.beginning_of_week.beginning_of_day, Date.today.end_of_week.end_of_day]
        @abstract_model.send(:build_statement, :field, type, "", "last_week").should ==
          ["(field BETWEEN ? AND ?)", 1.week.ago.to_date.beginning_of_week.beginning_of_day, 1.week.ago.to_date.end_of_week.end_of_day]
        @abstract_model.send(:build_statement, :field, type, "", "less_than").should be_nil
        @abstract_model.send(:build_statement, :field, type, "1", "less_than").
          should satisfy{|e| e.first == "(field > ?)" && (Time.now - e.last).between?(1.day.to_i, 2.day.to_i-1) }
        @abstract_model.send(:build_statement, :field, type, "1", "more_than").
          should satisfy{|e| e.first == "(field < ?)" && (Time.now - e.last).between?(1.day.to_i, 2.day.to_i-1) }
        @abstract_model.send(:build_statement, :field, type, "", "mmddyyyy").should be_nil
        @abstract_model.send(:build_statement, :field, type, "201105", "mmddyyyy").should be_nil
        @abstract_model.send(:build_statement, :field, type, "12312011", "mmddyyyy").to_s.should ==
          '["(field BETWEEN ? AND ?)", Sat, 31 Dec 2011 00:00:00 UTC +00:00, Sat, 31 Dec 2011 23:59:59 UTC +00:00]'
      end
    end

    it "supports enum type query" do
      @abstract_model.send(:build_statement, :field, :enum, "1", nil).should == ["(field IN (?))", ["1"]]
    end
  end

  describe "model attribute method" do
    before do
      @abstract_model = RailsAdmin::AbstractModel.new('Player')
    end

    it "#scoped returns relation object" do
      @abstract_model.scoped.should be_instance_of(ActiveRecord::Relation)
    end

    it "#table_name works" do
      @abstract_model.table_name.should == 'players'
    end

    it "#serialized_attributes works" do
      RailsAdmin::AbstractModel.new('User').serialized_attributes.keys.should == ["roles"]
    end
  end
end
