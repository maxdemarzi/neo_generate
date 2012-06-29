require 'rubygems'
require 'neography'
require 'forgery'
require 'uri'

  # Generate sample data and load into graph
  # 
  # Nodes
  #   Users             21,000
  #   Companies          4,000
  #   Activity            1.2M
  #   Item                1.3M 
  #   Entity              3.5M
  #   Tags              20,000
  #
  # Relationships
  #  Users            -[:belongs_to]-> Companies
  #  User             -[:performs]->   Activity
  #  Activity         -[:belongs_to]-> Item
  #  Item             -[:references]-> Entity
  #  Item             -[:tagged]->     Tags
  #
  def create_graph
    create_node_properties
    create_nodes
    create_relationship_properties
    create_relationships
  end  

  def create_node_properties
    # Stage Nodes
    node_properties = ["property1", "property2"]
    generate_node_properties(node_properties)  
  end

  def create_relationship_properties
    # Stage Relationships
    rel_properties = ["property1", "property2"]
    generate_rel_properties(rel_properties)
  end

  def create_nodes
    # Define Node Property Values
    node_values    = [lambda { generate_text              }, lambda { generate_text              }]
    user_values    = [lambda { Forgery::Name.full_name    }, lambda { Forgery::Personal.language }]
    company_values = [lambda { Forgery::Name.company_name }, lambda { Forgery::Name.industry     }]
    
   @nodes = {"user"     => { "start" => 1,
                             "end"   => 21000, 
                             "props" => user_values},
             "company"  => { "start" => 21001,
                             "end"   => 25000, 
                             "props" => company_values},
             "activity" => { "start" => 25001,
                             "end"   => 1225000, 
                             "props" => node_values},
             "item"     => { "start" => 1225001,
                             "end"   => 2525000, 
                             "props" => node_values},
             "entity"   => { "start" => 2525001,
                             "end"   => 6025000, 
                             "props" => node_values},
             "tag"      => { "start" => 6025001,
                             "end"   => 6045000, 
                             "props" => node_values}
    }
    
    # Write nodes to file
    @nodes.each{ |node| generate_nodes(node[0], node[1])}
  end

  def create_relationships
    # Define Relationsihp Property Values
    rel_values = [lambda { generate_text }, lambda { generate_text }]

    rels = {"user_to_company"  => { "from"  => @nodes["user"],
                                    "to"     => @nodes["company"],
                                    "number" => 21000,
                                    "type"   => "belongs_to",
                                    "props"  => rel_values,
                                    "connection" => :sequential },
            "user_to_activity" => { "from"  => @nodes["user"],
                                    "to"    => @nodes["activity"],
                                    "number" => 1200000,
                                    "type"   => "performs",
                                    "props"  => rel_values,
                                    "connection" => :random },
            "activity_to_item" => { "from"  => @nodes["activity"],
                                    "to"    => @nodes["item"],
                                    "number" => 3000000,
                                    "type"   => "belongs",
                                    "props"  => rel_values,
                                    "connection" => :random },
            "item_to_entity"   => { "from"  => @nodes["item"],
                                    "to"    => @nodes["entity"],
                                    "number" => 6000000,
                                    "type"   => "references",
                                    "props"  => rel_values,
                                    "connection" => :random },
            "item_to_tag"      => { "from"  => @nodes["item"],
                                    "to"    => @nodes["tag"],
                                    "number" => 250000,
                                    "type"   => "tagged",
                                    "props"  => rel_values,
                                    "connection" => :random }                                   
    }
  
    # Write relationships to file
    rels.each{ |rel| generate_rels(rel[1])}  
  end

  #  Recreate nodes.csv and set the node properties 
  #  
  def generate_node_properties(args)
    File.open("nodes.csv", "w") do |file|
      file.puts "type\t#{args.join("\t")}"
    end
  end

  #  Recreate rels.csv and set the relationship properties 
  #  
  def generate_rel_properties(args)
    File.open("rels.csv", "w") do |file|
      file.puts "start\tend\ttype\t#{args.join("\t")}"
    end
  end
  
  # Generate nodes given a type and hash
  #
  def generate_nodes(type, hash)
    puts "Generating #{(1 + hash["end"] - hash["start"])} #{type} nodes..."
    File.open("nodes.csv", "a") do |file|
      (1 + hash["end"] - hash["start"]).times do |t|
        file.puts "#{type}\t#{hash["props"].collect{|l| l.call}.join("\t")}" 
      end
    end
  end

  def generate_rels(hash)
    puts "Generating #{hash["number"]} #{hash["type"]} relationships..."
    File.open("rels.csv", "a") do |file|
    
      case hash["connection"]
        when :random      
          hash["number"].times do |t|
            file.puts "#{rand(hash["from"]["start"]..hash["from"]["end"])}\t#{rand(hash["to"]["start"]..hash["to"]["end"])}\t#{hash["type"]}\t#{hash["props"].collect{|l| l.call}.join("\t")}" 
          end
        when :sequential
          from_size = hash["from"]["end"] - hash["from"]["start"]
          to_size = hash["to"]["end"] - hash["to"]["start"]
          hash["number"].times do |t|
            file.puts "#{hash["from"]["start"] + (t % from_size)}\t#{hash["to"]["start"]  + (t % to_size)}\t#{hash["type"]}\t#{hash["props"].collect{|l| l.call}.join("\t")}" 
          end
      end
    end
  end

  # Generate random lowercase text of a given length 
  # 
  # Args
  #  length - Integer (default = 8)
  #
  def generate_text(length=8)
    chars = 'abcdefghjkmnpqrstuvwxyz'
    key = ''
    length.times { |i| key << chars[rand(chars.length)] }
    key
  end

  # Print the command needed to import the nodes.csv and rels.csv files
  #
  def load_graph
    # Prints the command to Load the data into Neo4j
    # 
    puts "Copy and Paste the following:"
    puts "java -server -Xmx4G -jar ../batch-import/target/batch-import-jar-with-dependencies.jar neo4j/data/graph.db nodes.csv rels.csv"    
  end 
  
  def index_graph
    neo = Neography::Rest.new
    begin
      if neo.execute_script("g.indices;").empty?  
        neo.execute_script("g.createAutomaticIndex('vertices', Vertex.class, null);") 
        neo.execute_script("AutomaticIndexHelper.reIndexElements(g, g.idx('vertices'), g.V);") if neo.execute_script("g.V.count();").to_i > 0
      end
    rescue Timeout::Error 
      puts "Indexing the graph is going to take some time, watch it on #{ENV['NEO4J_URL'] || "http://localhost:7474"}"
    end
  end