FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

COPY FormUpAPI.csproj ./
RUN dotnet restore FormUpAPI.csproj

COPY . .
RUN dotnet publish FormUpAPI.csproj -c Release -o /app/publish /p:UseAppHost=false

FROM build AS migrate
RUN dotnet tool install --global dotnet-ef --version 8.*
ENV PATH="$PATH:/root/.dotnet/tools"

FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS final
WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends libfontconfig1 libharfbuzz0b libfreetype6 \
    && rm -rf /var/lib/apt/lists/*

ENV ASPNETCORE_URLS=http://+:5000
ENV ASPNETCORE_ENVIRONMENT=Production
ENV DOTNET_RUNNING_IN_CONTAINER=true

COPY --from=build /app/publish .
RUN mkdir -p wwwroot/questions wwwroot/profile wwwroot/banner

EXPOSE 5000
ENTRYPOINT ["dotnet", "FormUpAPI.dll"]