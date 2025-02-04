import os
from openai import OpenAI

os.environ['OPENAI_API_KEY'] = os.getenv("OPENAI_API_KEY")

# Initialize the OpenAI client
client = OpenAI()

# Define the SQL schema using CREATE TABLE statements
sql_schema = """
CREATE TABLE Employees (
    EmployeeID INT PRIMARY KEY,
    FirstName VARCHAR(50),
    LastName VARCHAR(50),
    Department VARCHAR(50),
    Salary DECIMAL(10, 2),
    HireDate DATE
);

CREATE TABLE Departments (
    DepartmentID INT PRIMARY KEY,
    DepartmentName VARCHAR(50),
    Location VARCHAR(100)
);

CREATE TABLE Salaries (
    SalaryID INT PRIMARY KEY,
    EmployeeID INT,
    SalaryAmount DECIMAL(10, 2),
    EffectiveDate DATE,
    FOREIGN KEY (EmployeeID) REFERENCES Employees(EmployeeID)
);
"""

# Define the natural language question you want to ask about the SQL schema
question = "What is the average salary of employees in the 'Engineering' department?"

# Prepare the prompt for the chat completion
# This includes the SQL schema and the question, instructing the model to generate only the SQL query
prompt = f"""
You are an SQL expert. Based on the following SQL schema, generate an SQL query to answer the question below.

SQL Schema:
{sql_schema}

Question:
{question}

Only provide the SQL query, no explanations.
"""

# Specify the model to use (e.g., gpt-3.5-turbo)
model = "gpt-4o"

# Set parameters for the API call
max_tokens = 150  # Maximum number of tokens in the generated response
temperature = 0.7  # Controls randomness in output: lower means more deterministic
top_p = 0.95  # Nucleus sampling parameter

try:
    # Call the OpenAI Chat Completion API
    response = client.chat.completions.create(
        model=model,
        messages=[
            {"role": "system", "content": "You are an SQL expert."},
            {"role": "user", "content": prompt}
        ],
        max_tokens=max_tokens,
        temperature=temperature,
        top_p=top_p
    )

    # Extract the generated SQL query from the response
    generated_sql = response.choices[0].message.content.strip()
    print(generated_sql)

except Exception as e:
    # Handle any errors that occur during the API call
    print("An error occurred while calling the OpenAI API:", e)