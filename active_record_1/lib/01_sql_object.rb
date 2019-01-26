require_relative 'db_connection'
require 'active_support/inflector'
require 'byebug'
# NB: the attr_accessor we wrote in phase 0 is NOT used in the rest
# of this project. It was only a warm up.

class SQLObject
  def self.columns
    return @columns if @columns
    @columns = DBConnection.execute2(<<-SQL)
      SELECT
        *
      FROM
        '#{self.table_name}'
    SQL
    @columns = @columns.first.map { |col| col.to_sym }
  end

  def self.finalize!
    columns.each do |column|
      define_method(column) do 
        attributes[column]
      end

      define_method("#{column}=") do |var|
        attributes[column] = var
      end
    end
  end

  def self.table_name=(table_name)
    @table_name = table_name
  end

  def self.table_name
    @table_name || self.name.tableize
  end

  def self.all
    table = DBConnection.execute(<<-SQL)
      SELECT
        *
      FROM
        '#{self.table_name}'
    SQL
    self.parse_all(table)
  end

  def self.parse_all(results)
    results.map { |param| self.new(param) }
  end

  def self.find(id)
    table = self.all
    table.find do |row|
      return row if row.id == id
    end
    nil
  end

  def initialize(params = {})
    params.each do |attr_name, value|
      attr_name = attr_name.to_sym
      raise "unknown attribute '#{attr_name}'" unless self.class.columns.include?(attr_name)
      self.send("#{attr_name}=", value)
    end
  end

  def attributes
    @attributes ||= {}
  end

  def attribute_values
    self.class.columns.map do |col|
      self.send(col)
    end
  end

  def insert
    col_names = self.class.columns
    question_marks = col_names.map { "?" }

    col_names = col_names.join(", ")
    question_marks = question_marks.join(", ")
    values = attribute_values
    DBConnection.execute(<<-SQL, *values)
      INSERT INTO 
        '#{self.class.table_name}' (#{col_names})
      VALUES 
        (#{question_marks})
    SQL
    self.id = DBConnection.last_insert_row_id
  end

  def update
    update = self.class.columns.map { |col| col.to_s + " = ? " }.join(", ")
    values = attribute_values
    # byebug
    DBConnection.execute(<<-SQL, *values, id)
      UPDATE
        '#{self.class.table_name}'
      SET
        #{update}
      WHERE 
        id = ?
    SQL
    self.id = DBConnection.last_insert_row_id
  end

  def save
    if self.class.find(id)
      update
    else
      insert
    end
  end

  private
  def get_attributes
    col_names = self.class.columns
    question_marks = col_names.map { "?" }
    col_names = col_names.join(", ")
    question_marks = question_marks.join(", ")

    values = attribute_values
    [col_names, question_marks, values]
  end
end
