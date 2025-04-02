# Use the official Node.js image as a base
FROM node:23

# Set the working directory
WORKDIR /app

# Install pnpm globally
RUN npm install -g pnpm

# Copy the rest of your application code
COPY . .

# Expose the port that the app runs on
EXPOSE 3000

# Command to start the application
CMD ["./entrypoint.sh"]
